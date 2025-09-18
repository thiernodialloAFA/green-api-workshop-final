package com.example.optimized.config;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.filter.ShallowEtagHeaderFilter;

@Configuration
public class WebConfig {
    @Bean
    public FilterRegistrationBean<ShallowEtagHeaderFilter> etagFilter(){
        var bean = new FilterRegistrationBean<>(new ShallowEtagHeaderFilter());
        bean.addUrlPatterns("/books/*", "/books");
        bean.setName("etagFilter");
        bean.setOrder(1);
        return bean;
    }
}
