package codemwnci.bootsocket

import org.springframework.cloud.stream.annotation.StreamListener
import org.springframework.messaging.handler.annotation.Payload
import org.springframework.stereotype.Component

@Component
class GreetingsListener {
    @StreamListener("greetings-in")
    fun handleGreetings(@Payload greetings: Greetings) {
        println("Received greetings: $greetings")
    }
}
