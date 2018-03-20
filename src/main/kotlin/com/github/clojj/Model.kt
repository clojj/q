package com.github.clojj

import java.io.Serializable
import java.util.concurrent.Delayed
import java.util.concurrent.TimeUnit

class WsMsg(val msgType: String, val data: Any)

class User(val name: String)

data class Items(val items: List<ItemAndName>)

data class ItemAndName(val item: String, val name: String)

data class Delay(val timestamp: Long, val message: String, val now: Long) : Delayed, Serializable {

    override fun compareTo(other: Delayed?): Int {
        val otherDelay = other as Delay
        if (now < otherDelay.now) {
            return -1;
        }
        if (now > otherDelay.now) {
            return 1;
        }
        return 0;
    }

    override fun getDelay(p0: TimeUnit?): Long {
        return now - System.currentTimeMillis()
    }

}