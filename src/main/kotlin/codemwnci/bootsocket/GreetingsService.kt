package codemwnci.bootsocket

import org.springframework.messaging.MessageHeaders
import org.springframework.messaging.support.MessageBuilder
import org.springframework.stereotype.Service
import org.springframework.util.MimeTypeUtils

@Service
class GreetingsService(private val greetingsStreams: GreetingsStreams) {

    fun sendGreeting(greetings: Greetings) {

        println("Sending greetings $greetings")

        val messageChannel = greetingsStreams.outboundGreetings()
        messageChannel.send(MessageBuilder
                .withPayload(greetings)
                .setHeader(MessageHeaders.CONTENT_TYPE, MimeTypeUtils.APPLICATION_JSON)
                .build())
    }
}
