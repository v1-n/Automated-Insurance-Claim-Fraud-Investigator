package com.insurancefraud.messaging.consumer;

import com.insurancefraud.messaging.learningDto;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class LearningConsumer {

    @RabbitListener(queues = "fraud.queue1")
    public void consume(String str){
        log.info("Message received from the queue: " + str);
    }

    @RabbitListener(queues = "fraud.queue2",concurrency = "2")
    public void consumeJson(learningDto learningDto)throws InterruptedException{
        String tname = Thread.currentThread().getName();
        log.info("==> [{}] STARTED JSON job for user: {}", tname, learningDto.getName());
        Thread.sleep(3000);
        log.info("<== [{}] FINISHED JSON job for user: {}", tname, learningDto.getName());
    }
}
