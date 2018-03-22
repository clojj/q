package com.github.clojj

import jetbrains.exodus.bindings.StringBinding
import jetbrains.exodus.env.Environments
import jetbrains.exodus.env.Store
import jetbrains.exodus.env.StoreConfig
import jetbrains.exodus.env.Transaction
import org.jetbrains.annotations.NotNull
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
}

class ConfigItem {
    lateinit var name: String

    override fun toString(): String {
        return "Item(name='$name')"
    }
}

@Component
class Storage(private var config: SchalterConfig) : ServletContextListener {

    override fun contextInitialized(sce: ServletContextEvent?) {
    }

    override fun contextDestroyed(sce: ServletContextEvent?) {
        env.close()
    }

    val env = Environments.newInstance(".store")

    @PostConstruct
    fun init() {
        println("schalter configuration: $config")

        // initialize the store
        env.executeInTransaction { txn ->
            val store = env.openStore("Schalter", StoreConfig.WITHOUT_DUPLICATES, txn)
            config.configItems.forEach { configItem: ConfigItem ->
                initKey(store, txn, configItem.name)
            }
        }
    }

    fun store(key: String, value: String) {
        env.executeInTransaction { txn ->
            val store = env.openStore("Schalter", StoreConfig.WITHOUT_DUPLICATES, txn)
            store.put(txn, StringBinding.stringToEntry(key), StringBinding.stringToEntry(value))
        }
    }

    private fun initKey(store: @NotNull Store, txn: @NotNull Transaction, key: String) {
        val value = store.get(txn, StringBinding.stringToEntry(key))
        println("key:value = $key:$value")
        if (value == null) {
            store.put(txn, StringBinding.stringToEntry(key), StringBinding.stringToEntry("EMPTY"))
        }
    }

    fun allItems(): List<ItemAndName> {
        val items: MutableList<ItemAndName> = mutableListOf()
        env.executeInTransaction { txn ->
            val store = env.openStore("Schalter", StoreConfig.WITHOUT_DUPLICATES, txn)
            store.openCursor(txn).use { cursor ->
                while (cursor.next) {
                    items.add(ItemAndName(StringBinding.entryToString(cursor.key), StringBinding.entryToString(cursor.value)))
                }
            }
        }
        return items
    }

}

