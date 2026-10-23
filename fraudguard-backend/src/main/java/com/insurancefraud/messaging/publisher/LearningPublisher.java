package com.insurancefraud.messaging.publisher;

import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class LearningPublisher {

   private final RabbitTemplate rabbitTemplate;

    public LearningPublisher(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }

    public void sendMSG(){
        rabbitTemplate.convertAndSend("fraud.exchange", "fraud.routingkey1", "Hello from LearningPublisher");
        log.info("Message sent to the queue");
    }

    public void sendJsonMSG(){

    }
}
