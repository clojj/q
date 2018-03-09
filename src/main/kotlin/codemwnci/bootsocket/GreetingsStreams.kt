package codemwnci.bootsocket

import org.springframework.cloud.stream.annotation.Input
import org.springframework.cloud.stream.annotation.Output
import org.springframework.messaging.MessageChannel
import org.springframework.messaging.SubscribableChannel
import org.springframework.stereotype.Component

@Component
interface GreetingsStreams {

    @Input("greetings-in")
    fun inboundGreetings(): SubscribableChannel

    @Output("greetings-out")
    fun outboundGreetings(): MessageChannel
}
