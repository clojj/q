package codemwnci.bootsocket

import org.springframework.messaging.MessageHeaders
import org.springframework.messaging.support.MessageBuilder
import org.springframework.stereotype.Service
import org.springframework.util.MimeTypeUtils

@Service
class DelayService(private val delayStreams: DelayStreams) {

    fun sendDelay(delay: Delay) {

        println("sending delay $delay")

        val messageChannel = delayStreams.outboundGreetings()
        messageChannel.send(MessageBuilder
                .withPayload(delay)
                .setHeader(MessageHeaders.CONTENT_TYPE, MimeTypeUtils.APPLICATION_JSON)
                .build())
    }
}
