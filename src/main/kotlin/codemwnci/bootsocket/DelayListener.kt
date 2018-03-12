package codemwnci.bootsocket

import org.mapdb.DBMaker
import org.mapdb.Serializer
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

    private final val db = DBMaker.fileDB("mapStore")
            .transactionEnable()
            .fileMmapEnable()
            .closeOnJvmShutdown()
            .make()
    private final val treeMap = db.treeMap("treeMap", Serializer.STRING, Serializer.BYTE_ARRAY)
            .createOrOpen()

    @PostConstruct
    fun init() {
        if (treeMap["TODO"] == null) {
            treeMap["TODO"] = SerializationUtils.serialize(mutableListOf(Delay(0, "", 0)))
        }
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

            // update treeMap
            val list = SerializationUtils.deserialize(treeMap["TODO"]) as MutableList<Delay>
            list.add(delay)
            treeMap["TODO"] = SerializationUtils.serialize(list)
            db.commit()
        }
    }
}
