package com.github.clojj

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.boot.web.servlet.ServletListenerRegistrationBean
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.scheduling.TaskScheduler
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler
import org.springframework.stereotype.Component
import org.springframework.web.socket.CloseStatus
import org.springframework.web.socket.TextMessage
import org.springframework.web.socket.WebSocketSession
import org.springframework.web.socket.config.annotation.EnableWebSocket
import org.springframework.web.socket.config.annotation.WebSocketConfigurer
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry
import org.springframework.web.socket.handler.TextWebSocketHandler
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import javax.annotation.PostConstruct
import javax.servlet.ServletContextListener

@Component
class WebsocketHandler(private val storage: Storage, private val delayService: DelayService) : TextWebSocketHandler() {

    private val sessionMap = ConcurrentHashMap<WebSocketSession, User>()

    private var uids = AtomicLong(0)

    @PostConstruct
    fun init() {
        storage.allItems().forEach({ toggle: Toggle ->
            if (toggle.expiry > 0) {
                delayService.itemCountdown(toggle.item, toggle.expiry, this)
            }
        })
    }

    @Throws(Exception::class)
    override fun afterConnectionClosed(session: WebSocketSession, status: CloseStatus) {
        sessionMap -= session
    }

    public override fun handleTextMessage(session: WebSocketSession, message: TextMessage?) {
        println("Thread ${Thread.currentThread().id} session $session sessionMap ${System.identityHashCode(sessionMap)}")

        val json = ObjectMapper().readTree(message?.payload)
        val data = json.get("data")
        val text = data.asText()
        when (json.get("msgType").asText()) {
            "set" -> {
                val name = data.get("name").asText()
                sessionMap.getOrPut(session, { User(name) })

                val item = data.get("item").asText()
                var expiry = data.get("expiry").asLong()
                val toggle: Toggle
                if (expiry != 0L) {
                    expiry += System.currentTimeMillis()
                    delayService.itemCountdown(item, expiry, this)
                }
                storage.store(item, name, expiry)
                toggle = Toggle(item, name, expiry)
                broadcast(WsMsg("set", toggle))
            }

            "join" -> {
                val user = User(text)
                sessionMap.getOrPut(session, { user })
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
class WSConfig(val storage: Storage, val delayService: DelayService) : WebSocketConfigurer {
    override fun registerWebSocketHandlers(registry: WebSocketHandlerRegistry) {
        registry.addHandler(WebsocketHandler(storage, delayService), "/ws")
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

@Component
class DelayService(private val threadPoolTaskScheduler: TaskScheduler, private val storage: Storage) {

    fun itemCountdown(item: String, expiry: Long, handler: WebsocketHandler) {
        if (expiry > 0) {
            println("scheduling $item to expire in $expiry milliseconds")
            threadPoolTaskScheduler.schedule({
                println("${Thread.currentThread().name}: $item expired")
                storage.store(item, "", 0)
                handler.broadcast(WsMsg("set", Toggle(item, "", 0)))
            }, Instant.ofEpochMilli(expiry))
        }
    }
}
