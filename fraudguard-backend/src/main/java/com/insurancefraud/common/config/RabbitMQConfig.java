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

    @Value("${rabbitmq.claim.analysis.dlx}")
    private String deadLetterExchange;

    @Bean
    public Queue claimAnalysisQueue(){
        return QueueBuilder
                .durable(queueClaimAnalysis)
                .deadLetterExchange(deadLetterExchange)
                .deadLetterRoutingKey(queueClaimAnalysis + ".dlq")
                .build();
    }

    @Bean
    public Queue deadLetterQueue() {
        return QueueBuilder.durable(queueClaimAnalysis + ".dlq").build();
    }

    @Bean
    public DirectExchange deadLetterExchange() {
        return new DirectExchange(deadLetterExchange, true, false);
    }

    @Bean
    public Binding deadLetterBinding(){
        return BindingBuilder.bind(deadLetterQueue())
                .to(deadLetterExchange())
                .with(queueClaimAnalysis + ".dlq");
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
    public Binding claimDocumentAddedBinding() {
        return BindingBuilder
                .bind(claimAnalysisQueue())
                .to(eventsExchange())
                .with("claim.document.added");
    }

    @Bean
    public Binding claimAnalysisRerunBinding() {
        return BindingBuilder
                .bind(claimAnalysisQueue())
                .to(eventsExchange())
                .with("claim.analysis.rerun");
    }


    @Bean
    public MessageConverter messageConverter(){
        return new JacksonJsonMessageConverter();
    }



    @Bean
    public RabbitAdmin rabbitAdmin(ConnectionFactory connectionFactory) {
        RabbitAdmin rabbitAdmin = new RabbitAdmin(connectionFactory);
        rabbitAdmin.setAutoStartup(true);
        return rabbitAdmin;
    }
}
