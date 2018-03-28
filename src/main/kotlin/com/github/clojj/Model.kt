package com.github.clojj

class WsMsg(val msgType: String, val data: Any)

class User(val name: String)

data class Toggle(val item: String, val name: String, val expiry: Long)
