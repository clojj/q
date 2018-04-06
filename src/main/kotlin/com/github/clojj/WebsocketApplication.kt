package com.github.clojj

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.boot.web.servlet.ServletListenerRegistrationBean
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.context.annotation.Scope
import org.springframework.stereotype.Component
import org.springframework.web.socket.CloseStatus
import org.springframework.web.socket.TextMessage
import org.springframework.web.socket.WebSocketSession
import org.springframework.web.socket.config.annotation.EnableWebSocket
import org.springframework.web.socket.config.annotation.WebSocketConfigurer
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry
import org.springframework.web.socket.handler.TextWebSocketHandler
import java.util.concurrent.ConcurrentHashMap
import javax.servlet.ServletContextListener

@Scope("singleton")
@Component
class WebsocketHandler(private val storage: Storage) : TextWebSocketHandler() {

    private val sessionMap = ConcurrentHashMap<WebSocketSession, User>()

    @Throws(Exception::class)
    override fun afterConnectionClosed(session: WebSocketSession, status: CloseStatus) {
        sessionMap -= session
    }

    private val itemMap = ConcurrentHashMap<String, Boolean>()

    public override fun handleTextMessage(session: WebSocketSession, message: TextMessage?) {
        println("Thread ${Thread.currentThread().id} session $session sessionMap ${System.identityHashCode(sessionMap)}")

        val json = ObjectMapper().readTree(message?.payload)
        val data = json.get("data")
        val text = data.asText()
        when (json.get("msgType").asText()) {
            "beingSet" -> {
                itemMap.getOrPut(text, {true})

                broadcastToOthers(session, WsMsg("beingSet", text))
            }

            "set" -> {
                val item = data.get("item").asText()
                itemMap.getOrPut(item, {false})

                val name = data.get("name").asText()
                sessionMap.getOrPut(session, { User(name) })

                var expiry = data.get("expiry").asLong()
                val toggle: Toggle
                if (expiry != 0L) {
                    expiry += System.currentTimeMillis()
                }
                storage.store(item, name, expiry)
                toggle = Toggle(item, name, expiry)
                broadcast(WsMsg("set", toggle))
            }

            "join" -> {
                val user = User(text)
                sessionMap.getOrPut(session, { user })
//                TODO also send itemMap state
                session.sendMessage(TextMessage(objectMapper.writeValueAsString(WsMsg("allItems", storage.allItems()))))
            }
        }
    }

    private val objectMapper = jacksonObjectMapper()

    private fun emit(session: WebSocketSession, msg: WsMsg) = session.sendMessage(TextMessage(jacksonObjectMapper().writeValueAsString(msg)))

    fun broadcast(msg: WsMsg) = sessionMap.forEach { emit(it.key, msg) }

    private fun broadcastToOthers(me: WebSocketSession, msg: WsMsg) = sessionMap.filterNot { it.key == me }.forEach { emit(it.key, msg) }

}

@Configuration
@EnableWebSocket
class WSConfig(val websocketHandler: WebsocketHandler) : WebSocketConfigurer {
    override fun registerWebSocketHandlers(registry: WebSocketHandlerRegistry) {
        registry.addHandler(websocketHandler, "/ws")
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
