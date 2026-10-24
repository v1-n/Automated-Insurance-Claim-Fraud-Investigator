package com.insurancefraud.common.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitAdmin;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.JacksonJsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    @Value("${rabbitmq.exchange.events}")
    private String exchangeEvents;

    @Value("${rabbitmq.queue.claim.analysis}")
    private String queueClaimAnalysis;

    @Value("${rabbitmq.routing.key.claim.analysis}")
    private String routingKeyClaimAnalysis;

    @Bean
    public Queue claimAnalysisQueue(){
        return new Queue(queueClaimAnalysis,true);
    }

    @Bean
    public TopicExchange eventsExchange() {
        return new TopicExchange(exchangeEvents,true,false);
    }

    @Bean
    public Binding claimAnalysisbinding() {
        return BindingBuilder
                .bind(claimAnalysisQueue())
                .to(eventsExchange())
                .with(routingKeyClaimAnalysis);
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


    @Bean
    public RabbitAdmin rabbitAdmin(ConnectionFactory connectionFactory) {
        RabbitAdmin rabbitAdmin = new RabbitAdmin(connectionFactory);
        rabbitAdmin.setAutoStartup(true);
        return rabbitAdmin;
    }
}
