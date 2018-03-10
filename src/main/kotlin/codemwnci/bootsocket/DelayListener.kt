package codemwnci.bootsocket

import org.springframework.cloud.stream.annotation.StreamListener
import org.springframework.messaging.handler.annotation.Payload
import org.springframework.stereotype.Component
import java.util.concurrent.DelayQueue
import java.util.concurrent.TimeUnit
import javax.annotation.PostConstruct

@Component
class DelayListener {

    val delayQueue = DelayQueue<Delay>();

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
    fun handleDelay(@Payload delay: Delay) {
        if (delay.getDelay(TimeUnit.MILLISECONDS) > 0) {
            println("queuing delay: $delay")
            delayQueue.add(delay)
        }
    }
}
