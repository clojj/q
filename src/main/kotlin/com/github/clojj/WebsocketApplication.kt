package com.github.clojj

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import org.springframework.boot.autoconfigure.SpringBootApplication
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
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong


class WebsocketHandler() : TextWebSocketHandler() {

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
                val itemAndName = ItemAndName(data.get("item").asText(), data.get("name").asText())

                if (sessionMap[session] == null) {
                    val user = User(itemAndName.name)
                    sessionMap[session!!] = user
                }

                broadcast(WsMsg("set", itemAndName))
            }

//            TODO remove these ?
            "join" -> {
                println("Thread.currentThread().id = ${Thread.currentThread().id}")
                val user = User(text)
                sessionMap[session!!] = user
                // tell this user about all other users
                if (text == "newly joined") {
                    sessionMap.values.map { sessionUser -> emit(session, WsMsg("join", sessionUser.name)) }
                }
                // tell all other users, about this user
                broadcast(WsMsg("join", user.name))
            }
            "say" -> {
                broadcast(WsMsg("say", text))
                sendDelay(text, session.toString())
            }
        }
    }

    private fun emit(session: WebSocketSession, msg: WsMsg) = {
        if (session.isOpen) {
            session.sendMessage(TextMessage(jacksonObjectMapper().writeValueAsString(msg)))
        }
    }

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
class WSConfig() : WebSocketConfigurer {
    override fun registerWebSocketHandlers(registry: WebSocketHandlerRegistry) {
        registry.addHandler(WebsocketHandler(), "/chat")
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