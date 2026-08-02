package cbt.order;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.web.ErrorResponseException;
import jakarta.servlet.ServletException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Order's API is geen grens en heeft dus geen gepubliceerd Error-schema, maar volgt hem
 * wel: geen stacktrace en geen intern pad naar buiten.
 */
@RestControllerAdvice
public class ApiExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(ApiExceptionHandler.class);

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
     * vangt het vangnet hieronder ze op en wordt een 404 of een 405 een 500.
     *
     * ServletException dekt die hele familie in één keer; ze implementeren allemaal
     * ErrorResponse en dragen dus hun eigen status. Los opsommen betekent dat je bij de
     * volgende soort opnieuw een 500 uitdeelt.
     */
    @ExceptionHandler({ErrorResponseException.class, ServletException.class})
    public ResponseEntity<ErrorResponse> afgebeeld(Exception fout) {
        if (!(fout instanceof org.springframework.web.ErrorResponse afgebeeld)) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ErrorResponse("INTERNAL_ERROR", "unexpected error"));
        }
        HttpStatusCode status = afgebeeld.getStatusCode();
        String code = switch (status.value()) {
            case 404 -> "RESOURCE_NOT_FOUND";
            case 405 -> "METHOD_NOT_ALLOWED";
            case 415 -> "UNSUPPORTED_MEDIA_TYPE";
            default -> status.is4xxClientError() ? "INVALID_REQUEST" : "INTERNAL_ERROR";
        };
        // De headers gaan mee: bij een 405 zit daar de Allow-header in die RFC 9110 eist,
        // en die is van Spring afkomstig. Zelf samenstellen zou hem laten verouderen.
        return ResponseEntity.status(status).headers(afgebeeld.getHeaders())
                .body(new ErrorResponse(code, "request cannot be served"));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> onverwacht(Exception fout) {
        // Naar buiten niets, in het log alles. Een 500 zonder spoor is niet te
        // onderzoeken, en dat merk je pas als je hem hebt.
        LOG.error("onverwachte fout", fout);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse("INTERNAL_ERROR", "unexpected error"));
    }
}
