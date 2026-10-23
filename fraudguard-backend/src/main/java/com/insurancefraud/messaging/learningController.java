package com.insurancefraud.messaging;


import com.insurancefraud.messaging.publisher.LearningPublisher;
import com.insurancefraud.messaging.publisher.learningJsonPublisher;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping("/learning")
public class learningController {

    private final LearningPublisher learningPublisher;
    private final learningJsonPublisher learningJsonPublisher;


    public learningController(LearningPublisher learningPublisher, learningJsonPublisher learningJsonPublisher) {
        this.learningPublisher = learningPublisher;
        this.learningJsonPublisher = learningJsonPublisher;
    }

    @GetMapping("/send-message")
    public String sendMessage() {
        learningPublisher.sendMSG();
        return "Message sent to the queue";
    }

    @PostMapping("/send-json-msg")
    public ResponseEntity<learningDto> sendJsonMessage(@RequestBody learningDto learningDto) {
        learningJsonPublisher.sendJsonMSG(learningDto);

        return ResponseEntity.ok(learningDto);
    }
}
