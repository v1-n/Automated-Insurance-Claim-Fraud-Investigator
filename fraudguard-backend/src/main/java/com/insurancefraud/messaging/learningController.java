package com.insurancefraud.messaging;


import com.insurancefraud.messaging.publisher.LearningPublisher;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
@RequestMapping("/learning")
public class learningController {

    private final LearningPublisher learningPublisher;

    public learningController(LearningPublisher learningPublisher) {
        this.learningPublisher = learningPublisher;
    }

    @GetMapping("/send-message")
    public String sendMessage() {
        learningPublisher.sendMSG();
        return "Message sent to the queue";
    }
}
