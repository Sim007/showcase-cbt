package cbt.order;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Order's API is geen grens en heeft dus geen gepubliceerd Error-schema, maar volgt hem
 * wel: geen stacktrace en geen intern pad naar buiten.
 */
@RestControllerAdvice
public class ApiExceptionHandler {

    public record ErrorResponse(String code, String message) {
    }

    @ExceptionHandler(OrderNotFoundException.class)
    public ResponseEntity<ErrorResponse> nietGevonden(OrderNotFoundException fout) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new ErrorResponse("ORDER_NOT_FOUND", fout.getMessage()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> onverwacht(Exception fout) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("INTERNAL_ERROR", "unexpected error"));
    }
}
