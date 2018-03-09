package codemwnci.bootsocket

import codemwnci.bootsocket.GreetingsStreams
import org.springframework.cloud.stream.annotation.EnableBinding

@EnableBinding(GreetingsStreams::class)
class StreamsConfig
