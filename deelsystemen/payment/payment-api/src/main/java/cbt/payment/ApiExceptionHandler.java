package cbt.payment;

import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.ErrorResponseException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
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

    /**
     * Fouten die Spring zelf al op een status heeft afgebeeld: onbekend pad, verkeerde
     * methode, niet-ondersteund mediatype. Die status blijft staan — zonder deze handler
     * vangt het vangnet hieronder ze op en wordt een 404 een 500.
     */
    @ExceptionHandler({ErrorResponseException.class, NoResourceFoundException.class})
    public ResponseEntity<ErrorResponse> afgebeeld(Exception fout) {
        HttpStatusCode status = fout instanceof org.springframework.web.ErrorResponse afgebeeld
                ? afgebeeld.getStatusCode()
                : HttpStatus.INTERNAL_SERVER_ERROR;
        String code = status.value() == 404 ? "RESOURCE_NOT_FOUND" : "INVALID_REQUEST";
        return ResponseEntity.status(status).body(new ErrorResponse(code, "request cannot be served"));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> onverwacht(Exception fout) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("INTERNAL_ERROR", "unexpected error"));
    }
}
