package cbt.payment;

/**
 * Het Error-schema uit het contract: uitsluitend code en message. Geen stacktrace en geen
 * intern pad, ook niet bij een onverwachte fout.
 */
public record ErrorResponse(String code, String message) {
}
