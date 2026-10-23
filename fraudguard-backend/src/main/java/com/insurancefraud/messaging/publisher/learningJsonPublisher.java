package com.insurancefraud.messaging.publisher;

import com.insurancefraud.messaging.learningDto;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class learningJsonPublisher {
    private final RabbitTemplate rabbitTemplate;

    public learningJsonPublisher(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }

    public void sendJsonMSG(learningDto learningDto) {
        rabbitTemplate.convertAndSend("fraud.exchange", "fraud.routingkey2", learningDto);
        log.info("JSON Message sent to the queue: " + learningDto);
    }
}
