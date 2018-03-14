package codemwnci.bootsocket

import jetbrains.exodus.ArrayByteIterable
import jetbrains.exodus.bindings.StringBinding
import jetbrains.exodus.env.Environments
import jetbrains.exodus.env.StoreConfig
import jetbrains.exodus.env.Transaction
import jetbrains.exodus.env.TransactionalExecutable
import org.jetbrains.annotations.NotNull
import org.springframework.cloud.stream.annotation.StreamListener
import org.springframework.messaging.handler.annotation.Headers
import org.springframework.messaging.handler.annotation.Payload
import org.springframework.stereotype.Component
import org.springframework.util.SerializationUtils
import java.util.concurrent.DelayQueue
import java.util.concurrent.TimeUnit
import javax.annotation.PostConstruct


@Component
class DelayListener {

    private val delayQueue = DelayQueue<Delay>()

    @PostConstruct
    fun init() {
        Thread(Runnable {
            while (true) {
                val delay = delayQueue.take()
                println("Delay expired: $delay")
            }
        }).start()
    }

    @StreamListener("greetings-in")
    fun handleDelay(@Payload delay: Delay, @Headers headers: Map<*, *>) {
        println("headers = $headers")
        if (delay.getDelay(TimeUnit.MILLISECONDS) > 0) {
            println("queuing delay: $delay at ${System.currentTimeMillis()}")
            delayQueue.add(delay)

            // update store
            val env = Environments.newInstance(".myAppData")
            env.executeInTransaction { txn ->
                val store = env.openStore("Messages", StoreConfig.WITHOUT_DUPLICATES, txn)
                val bytes = SerializationUtils.serialize(delay)
                store.put(txn, StringBinding.stringToEntry("Delay"), ArrayByteIterable(bytes))
            }
            env.close()
        }
    }
}
