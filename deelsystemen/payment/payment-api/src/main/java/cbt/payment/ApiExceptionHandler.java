package cbt.payment;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Elke foutresponse volgt het Error-schema uit het contract. Geen stacktrace, geen intern
 * pad, ook niet bij een onverwachte fout: de melding van de uitzondering gaat nooit
 * ongefilterd naar buiten.
 */
@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(PaymentRuleException.class)
    public ResponseEntity<ErrorResponse> regel(PaymentRuleException fout) {
        return ResponseEntity.badRequest().body(new ErrorResponse(fout.getCode(), fout.getMessage()));
    }

    @ExceptionHandler(PaymentNotFoundException.class)
    public ResponseEntity<ErrorResponse> nietGevonden(PaymentNotFoundException fout) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new ErrorResponse("PAYMENT_NOT_FOUND", fout.getMessage()));
    }

    /**
     * Onleesbare of niet-conforme body. Hier komt ook een niet-gedeclareerd veld terecht:
     * het contract zegt additionalProperties: false, dus dat is een schending en geen detail
     * dat stilzwijgend mag meeliften.
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> onleesbaar(HttpMessageNotReadableException fout) {
        return ResponseEntity.badRequest()
                .body(new ErrorResponse("INVALID_REQUEST", "request body does not match the contract"));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> onverwacht(Exception fout) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("INTERNAL_ERROR", "unexpected error"));
    }
}
