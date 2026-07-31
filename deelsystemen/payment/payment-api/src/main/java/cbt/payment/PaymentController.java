package cbt.payment;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * De versie staat in het pad en niet in een header: bij een major moeten twee versies
 * naast elkaar geserveerd worden, en dan zie je in een demo letterlijk twee routes draaien.
 */
@RestController
@RequestMapping("/v1/payments")
public class PaymentController {

    private final PaymentService service;

    public PaymentController(PaymentService service) {
        this.service = service;
    }

    @PostMapping
    public ResponseEntity<PaymentResponse> create(@RequestBody PaymentRequest verzoek) {
        PaymentEntity betaling = service.create(verzoek);
        return ResponseEntity.status(HttpStatus.CREATED).body(naarResponse(betaling));
    }

    @GetMapping("/{paymentId}")
    public PaymentResponse get(@PathVariable String paymentId) {
        return service.find(paymentId)
                .map(PaymentController::naarResponse)
                .orElseThrow(() -> new PaymentNotFoundException(paymentId));
    }

    private static PaymentResponse naarResponse(PaymentEntity betaling) {
        return new PaymentResponse(betaling.getPaymentId(), betaling.getOrderId(), betaling.getStatus());
    }
}
