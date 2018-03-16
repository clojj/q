package codemwnci.bootsocket

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.boot.runApplication
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler
import org.springframework.web.socket.CloseStatus
import org.springframework.web.socket.TextMessage
import org.springframework.web.socket.WebSocketSession
import org.springframework.web.socket.config.annotation.EnableWebSocket
import org.springframework.web.socket.config.annotation.WebSocketConfigurer
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry
import org.springframework.web.socket.handler.TextWebSocketHandler
import java.util.concurrent.atomic.AtomicLong


class User(val id: Long, val name: String)

class WsMsg(val msgType: String, val data: Any)

class WebsocketHandler(private val delayService: DelayService) : TextWebSocketHandler() {

    private val sessionList = HashMap<WebSocketSession, User>()
    private var uids = AtomicLong(0)

    @Throws(Exception::class)
    override fun afterConnectionClosed(session: WebSocketSession, status: CloseStatus) {
        sessionList -= session
    }

    public override fun handleTextMessage(session: WebSocketSession?, message: TextMessage?) {
        val json = ObjectMapper().readTree(message?.payload)
        // {msgType: "join", data: "name"}
        val text = json.get("data").asText()
        when (json.get("msgType").asText()) {
            "join" -> {
                val user = User(uids.getAndIncrement(), text)
                sessionList.put(session!!, user)
                // tell this user about all other users
                emit(session, WsMsg("users", sessionList.values))
                // tell all other users, about this user
                broadcastToOthers(session, WsMsg("join", user.name))
            }
            "say" -> {
                broadcast(WsMsg("say", text))
                sendDelay(text, session.toString())
            }
        }
    }

    private fun emit(session: WebSocketSession, msg: WsMsg) = session.sendMessage(TextMessage(jacksonObjectMapper().writeValueAsString(msg)))

    private fun broadcast(msg: WsMsg) = sessionList.forEach { emit(it.key, msg) }

    private fun broadcastToOthers(me: WebSocketSession, msg: WsMsg) = sessionList.filterNot { it.key == me }.forEach { emit(it.key, msg) }

    private fun sendDelay(delayMillis: String, session: String) {
        val interval = delayMillis.toLong()
        val delay = Delay(interval, "Delay from $session", System.currentTimeMillis() + interval)
        delayService.sendDelay(delay)
    }
}

@Configuration
@EnableWebSocket
class WSConfig(val delayService: DelayService) : WebSocketConfigurer {
    override fun registerWebSocketHandlers(registry: WebSocketHandlerRegistry) {
        registry.addHandler(WebsocketHandler(delayService), "/chat")
    }
}


@SpringBootApplication
class WebsocketApplication

fun main(args: Array<String>) {
    runApplication<WebsocketApplication>(*args)
}

@Configuration
class ThreadPoolTaskSchedulerConfig {

    @Bean
    fun threadPoolTaskScheduler(): ThreadPoolTaskScheduler {
        val threadPoolTaskScheduler = ThreadPoolTaskScheduler()
        threadPoolTaskScheduler.poolSize = 5
        threadPoolTaskScheduler.threadNamePrefix = "ThreadPoolTaskScheduler"
        return threadPoolTaskScheduler
    }
}