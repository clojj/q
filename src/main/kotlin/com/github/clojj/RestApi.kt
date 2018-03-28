package com.github.clojj

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController

@RestController
class RestApi(private val storage: Storage) {

    @GetMapping("/items")
    fun items(): List<Toggle> {
        return storage.allItems()
    }

}
