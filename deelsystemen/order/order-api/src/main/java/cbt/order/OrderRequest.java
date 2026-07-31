package cbt.order;

import java.math.BigDecimal;

/** Requestbody van POST /orders. Deze API is geen grens en staat dus niet in het register. */
public record OrderRequest(BigDecimal amount, String currency) {
}
