package com.insurancefraud.common.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.JacksonJsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    @Bean
    public Queue queue1() {
        return new Queue("fraud.queue1", true);
    }

    @Bean
    public Queue queue2(){
        return  new Queue("fraud.queue2", true);
    }

    @Bean
    public TopicExchange exchange() {
        return new TopicExchange("fraud.exchange");
    }



    @Bean
    public Binding binding() {
        return BindingBuilder
                .bind(queue1())
                .to(exchange())
                .with("fraud.routingkey1");
    }

    @Bean
    public Binding binding2(){
        return BindingBuilder
                .bind(queue2())
                .to(exchange())
                .with("fraud.routingkey2");
    }

    @Bean
    public MessageConverter messageConverter(){
        return new JacksonJsonMessageConverter();
    }

    @Bean
    public AmqpTemplate amqpTemplate(ConnectionFactory connectionFactory){
        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
        rabbitTemplate.setMessageConverter(messageConverter());
        return rabbitTemplate;
    }


/*
* this 3 are created by spring automatically, so we don't need to create them manually
* @Bean ConnectionFactory, RabbitmqTemplate,rabbitAdmin
* */
}
