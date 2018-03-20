package com.github.clojj

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import javax.annotation.PreDestroy

@RestController
class RestApi(private val storage: Storage) {

    @GetMapping("/items")
    fun items(): Items {
        return Items(storage.allItems())
    }

}
