package com.github.clojj

class WsMsg(val msgType: String, val data: Any)

data class TotalState(val beingSetList: List<Boolean>, val items: List<Toggle>)

data class Toggle(val item: String, val name: String, val expiry: Long)

class User(val name: String)
