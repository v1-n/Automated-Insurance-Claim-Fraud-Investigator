package com.insurancefraud.common.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import java.time.Duration;

@Configuration
public class RestClientConfig {

    @Value("${ai.fraud.service.url:http://localhost:8000/api/v1/analyze-claim}")
    private String baseUrl;

    @Value("${ai.fraud.service.connect-timeout:3s}")
    private Duration connectTimeout;

    @Value("${ai.fraud.service.read-timeout:90s}")
    private Duration readTimeout;
    @Bean
    public RestClient aiRestClient() {
            SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
            requestFactory.setConnectTimeout((int) connectTimeout.toMillis());
            requestFactory.setReadTimeout((int) readTimeout.toMillis());
            return RestClient.builder()
                    .baseUrl(baseUrl)
                    .requestFactory(requestFactory)
                    .build();
        }
}
