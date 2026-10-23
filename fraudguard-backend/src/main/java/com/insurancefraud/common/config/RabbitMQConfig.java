package com.insurancefraud.common.config;

import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    @Bean
    public Queue queue() {
        return new Queue("fraud.queue", true);
    }

    @Bean
    public TopicExchange exchange() {
        return new TopicExchange("fraud.exchange");
    }

    @Bean
    public Binding binding() {
        return BindingBuilder
                .bind(queue())
                .to(exchange())
                .with("fraud.routingkey");
    }


/*
* this 3 are created by spring automatically, so we don't need to create them manually
* @Bean ConnectionFactory, RabbitmqTemplate,rabbitAdmin
* */
}
