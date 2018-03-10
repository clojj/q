package codemwnci.bootsocket

import java.util.concurrent.Delayed
import java.util.concurrent.TimeUnit

data class Delay(val timestamp: Long, val message: String, val now: Long) : Delayed {
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