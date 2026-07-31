package cbt.order;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * De eigen API van Order. Hier wisselt geen eigenaarschap, dus dit is geen grens en er
 * staat geen contract van in het register.
 */
@RestController
@RequestMapping("/orders")
public class OrderController {

    private final OrderService service;

    public OrderController(OrderService service) {
        this.service = service;
    }

    @PostMapping
    public ResponseEntity<OrderResponse> place(@RequestBody OrderRequest verzoek) {
        OrderEntity bestelling = service.place(verzoek);
        return ResponseEntity.status(HttpStatus.CREATED).body(naarResponse(bestelling));
    }

    @GetMapping("/{orderId}")
    public OrderResponse get(@PathVariable String orderId) {
        return service.find(orderId)
                .map(OrderController::naarResponse)
                .orElseThrow(() -> new OrderNotFoundException(orderId));
    }

    private static OrderResponse naarResponse(OrderEntity bestelling) {
        return new OrderResponse(
                bestelling.getOrderId(), bestelling.getStatus(), bestelling.getPaymentId());
    }
}
