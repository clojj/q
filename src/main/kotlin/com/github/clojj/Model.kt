package com.github.clojj

class WsMsg(val msgType: String, val data: Any)

class User(val name: String)

data class Items(val items: List<ItemAndName>)

data class ItemAndName(val item: String, val name: String)
