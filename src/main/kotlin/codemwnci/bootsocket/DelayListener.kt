package codemwnci.bootsocket

import jetbrains.exodus.ArrayByteIterable
import jetbrains.exodus.bindings.StringBinding
import jetbrains.exodus.env.Environments
import jetbrains.exodus.env.StoreConfig
import org.springframework.cloud.stream.annotation.StreamListener
import org.springframework.messaging.handler.annotation.Headers
import org.springframework.messaging.handler.annotation.Payload
import org.springframework.scheduling.TaskScheduler
import org.springframework.stereotype.Component
import org.springframework.util.SerializationUtils
import java.time.Instant
import java.util.concurrent.TimeUnit


@Component
class DelayListener(private val threadPoolTaskScheduler: TaskScheduler) {

    @StreamListener("greetings-in")
    fun handleDelay(@Payload delay: Delay, @Headers headers: Map<*, *>) {
        println("headers = $headers")
        val delayMillis = delay.getDelay(TimeUnit.MILLISECONDS)
        if (delayMillis > 0) {

            println("scheduling delay: $delay at ${System.currentTimeMillis()}")
            threadPoolTaskScheduler.schedule({
                println("${Thread.currentThread().name}: delay expired: $delay")
            }, Instant.ofEpochMilli(System.currentTimeMillis() + delayMillis))

            // update store
            val env = Environments.newInstance(".qstore")
            env.executeInTransaction { txn ->
                val store = env.openStore("Messages", StoreConfig.WITHOUT_DUPLICATES, txn)

                val getbytes = store.get(txn, StringBinding.stringToEntry("Delay"))
                val existingDelay = SerializationUtils.deserialize(getbytes?.bytesUnsafe) as Delay
                println("existingDelay = $existingDelay")

                val bytes = SerializationUtils.serialize(delay)
                store.put(txn, StringBinding.stringToEntry("Delay"), ArrayByteIterable(bytes))
            }
            env.close()
        }
    }
}
