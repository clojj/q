package codemwnci.bootsocket

import org.mapdb.DBMaker
import org.mapdb.Serializer
import org.springframework.cloud.stream.annotation.StreamListener
import org.springframework.messaging.handler.annotation.Headers
import org.springframework.messaging.handler.annotation.Payload
import org.springframework.stereotype.Component
import java.util.concurrent.DelayQueue
import java.util.concurrent.TimeUnit
import javax.annotation.PostConstruct

@Component
class DelayListener {

    private val delayQueue = DelayQueue<Delay>()

    private final val treeMap = DBMaker.fileDB("mapStore")
            .transactionEnable()
            .fileMmapEnable()
            .closeOnJvmShutdown()
            .make().treeMap("treeMap", Serializer.STRING, Serializer.STRING).createOrOpen()

    @PostConstruct
    fun init() {
        treeMap.forEach({ k, v -> println("k = $k\nv = $v") })

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
            treeMap["TODO"] = delay.toString()
            treeMap.store.commit()
        }
    }
}
