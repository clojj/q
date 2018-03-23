package com.github.clojj

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.boot.web.servlet.ServletListenerRegistrationBean
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
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import javax.servlet.ServletContextListener


class WebsocketHandler(val storage: Storage) : TextWebSocketHandler() {

    private val sessionMap = ConcurrentHashMap<WebSocketSession, User>()

    private var uids = AtomicLong(0)

    @Throws(Exception::class)
    override fun afterConnectionClosed(session: WebSocketSession, status: CloseStatus) {
        sessionMap -= session
    }

    public override fun handleTextMessage(session: WebSocketSession?, message: TextMessage?) {
        val json = ObjectMapper().readTree(message?.payload)
        val data = json.get("data")
        val text = data.asText()
        when (json.get("msgType").asText()) {
            "set" -> {
                val item = data.get("item").asText()
                val name = data.get("name").asText()

                sessionMap.getOrPut(session, { User(name) })
                storage.store(item, name)

                val itemAndName = ItemAndName(item, name)
                broadcastToOthers(session!!, WsMsg("set", itemAndName))
            }

//            TODO remove these ?
            "join" -> {
                println("Thread-ID ${Thread.currentThread().id} session $session")
                val user = User(text)
                sessionMap.getOrPut(session, { user })
//                session!!.sendMessage(TextMessage(objectMapper.writeValueAsString(user)))
//                broadcastToOthers(session, WsMsg("join", user.name))

            }
            "say" -> {
                broadcast(WsMsg("say", text))
                sendDelay(text, session.toString())
            }
        }
    }

    private val objectMapper = jacksonObjectMapper()

    private fun emit(session: WebSocketSession, msg: WsMsg) = session.sendMessage(TextMessage(jacksonObjectMapper().writeValueAsString(msg)))

    private fun broadcast(msg: WsMsg) = sessionMap.forEach { emit(it.key, msg) }

    private fun broadcastToOthers(me: WebSocketSession, msg: WsMsg) = sessionMap.filterNot { it.key == me }.forEach { emit(it.key, msg) }

    private fun sendDelay(delayMillis: String, session: String) {
        val interval = delayMillis.toLong()
        val delay = Delay(interval, "Delay from $session", System.currentTimeMillis() + interval)
        // TODO
    }

}

@Configuration
@EnableWebSocket
class WSConfig(val storage: Storage) : WebSocketConfigurer {
    override fun registerWebSocketHandlers(registry: WebSocketHandlerRegistry) {
        registry.addHandler(WebsocketHandler(storage), "/chat")
    }
}

@SpringBootApplication
class WebsocketApplication(val storage: Storage) {
    @Bean
    fun myServletListener(): ServletListenerRegistrationBean<ServletContextListener> {
        val srb = ServletListenerRegistrationBean<ServletContextListener>()
        srb.listener = storage
        return srb
    }
}

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