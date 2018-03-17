package codemwnci.bootsocket

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import java.io.Serializable

data class Items(val items: List<ItemAndName>)
data class ItemAndName(val item: String, val name: String)

@RestController
class RestApi(private val storage: Storage) {

    @GetMapping("/items")
    fun items(): Items {
        return Items(storage.allItems())
    }
}
