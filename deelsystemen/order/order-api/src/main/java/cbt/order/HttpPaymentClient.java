package cbt.order;

import java.math.BigDecimal;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
public class HttpPaymentClient implements PaymentClient {

    private final RestClient restClient;

    public HttpPaymentClient(RestClient.Builder builder, @Value("${payment.base-url}") String baseUrl) {
        this.restClient = builder.baseUrl(baseUrl).build();
    }

    @Override
    public PaymentView create(String orderId, BigDecimal amount, String currency) {
        return restClient.post()
                .uri("/v1/payments")
                .body(Map.of("orderId", orderId, "amount", amount, "currency", currency))
                .retrieve()
                .body(PaymentView.class);
    }
}
