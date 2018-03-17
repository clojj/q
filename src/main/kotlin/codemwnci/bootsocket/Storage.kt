package codemwnci.bootsocket

import jetbrains.exodus.bindings.StringBinding
import jetbrains.exodus.env.Environments
import jetbrains.exodus.env.Store
import jetbrains.exodus.env.StoreConfig
import jetbrains.exodus.env.Transaction
import org.jetbrains.annotations.NotNull
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.context.annotation.Configuration
import org.springframework.stereotype.Component
import org.springframework.util.SerializationUtils
import javax.annotation.PostConstruct
import javax.annotation.PreDestroy


@ConfigurationProperties(prefix = "schalter")
@Configuration
class SchalterConfig {
    var items: MutableList<Item> = mutableListOf()
}

class Item {
    lateinit var name: String

    override fun toString(): String {
        return "Item(name='$name')"
    }
}

@Component
class Storage(private var config: SchalterConfig) {

    val env = Environments.newInstance(".store")

    @PostConstruct
    fun init() {
        println("config = $config")

        // initialize the store
        env.executeInTransaction { txn ->
            val store = env.openStore("Schalter", StoreConfig.WITHOUT_DUPLICATES, txn)
            config.items.forEach { item: Item ->
                initKey(store, txn, item.name)
            }
        }
    }

    @PreDestroy
    fun destroy() {
        env.close() // TODO
    }

    private fun initKey(store: @NotNull Store, txn: @NotNull Transaction, key: String) {
        val value = SerializationUtils.deserialize(store.get(txn, StringBinding.stringToEntry(key))?.bytesUnsafe)
        println("key:value = $key:$value")
        if (value == null) {
            store.put(txn, StringBinding.stringToEntry(key), StringBinding.stringToEntry("EMPTY"))
        }
    }

    fun allItems(): List<ItemAndName> {
        val items: MutableList<codemwnci.bootsocket.ItemAndName> = mutableListOf()
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

