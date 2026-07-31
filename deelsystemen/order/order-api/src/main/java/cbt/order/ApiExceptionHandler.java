package cbt.order;

import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.web.ErrorResponseException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
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
