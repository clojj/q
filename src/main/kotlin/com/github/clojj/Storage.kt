package com.github.clojj

import jetbrains.exodus.entitystore.Entity
import jetbrains.exodus.entitystore.PersistentEntityStores
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.context.annotation.Configuration
import org.springframework.stereotype.Component
import javax.annotation.PostConstruct
import javax.servlet.ServletContextEvent
import javax.servlet.ServletContextListener


@ConfigurationProperties(prefix = "schalter")
@Configuration
class SchalterConfig {
    var configItems: MutableList<ConfigItem> = mutableListOf()

    override fun toString(): String {
        return "SchalterConfig(configItems=$configItems)"
    }
}

class ConfigItem {
    lateinit var item: String

    override fun toString(): String {
        return "Item(item='$item')"
    }
}

@Component
class Storage(private var config: SchalterConfig) : ServletContextListener {

    private val ENTITY_TOGGLE: String = "TOGGLE"
    private val PROP_ITEM = "item"
    private val PROP_NAME = "name"
    private val PROP_EXPIRY = "expiry"

    override fun contextInitialized(sce: ServletContextEvent?) {
    }

    override fun contextDestroyed(sce: ServletContextEvent?) {
        entityStore.close()
    }

    val entityStore = PersistentEntityStores.newInstance(".entitystore")!!


    @PostConstruct
    fun init() {
        println("schalter configuration: $config")

        // initialize the store
        entityStore.executeInTransaction { txn ->
            config.configItems.forEach { configItem: ConfigItem ->
                val entityIterable = txn.find(ENTITY_TOGGLE, PROP_ITEM, configItem.item)
                if (entityIterable.isEmpty) {
                    val item = txn.newEntity(ENTITY_TOGGLE)
                    item.setProperty(PROP_ITEM, configItem.item)
                    item.setProperty(PROP_NAME, "")
                    item.setProperty(PROP_EXPIRY, 0L)
                }
            }
        }
    }

    fun store(item: String, name: String, expiry: Long) {
        entityStore.executeInTransaction { txn ->
            val entityIterable = txn.find(ENTITY_TOGGLE, PROP_ITEM, item)
            val first = entityIterable.first!!
            first.setProperty(PROP_NAME, name)
            first.setProperty(PROP_EXPIRY, expiry)
        }
    }

    fun allItems(): List<Toggle> {
        val items: MutableList<Toggle> = mutableListOf()
        entityStore.executeInTransaction { txn ->
            val entityIterable = txn.getAll(ENTITY_TOGGLE)
            entityIterable.forEach({ entity: Entity? ->
                items.add(Toggle(entity!!.getProperty(PROP_ITEM) as String, entity.getProperty(PROP_NAME) as String, entity.getProperty(PROP_EXPIRY) as Long))
            })
        }
        return items.sortedBy { toggle -> toggle.item }
    }

}

