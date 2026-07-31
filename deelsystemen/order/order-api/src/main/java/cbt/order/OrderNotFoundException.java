package cbt.order;

public class OrderNotFoundException extends RuntimeException {

    public OrderNotFoundException(String orderId) {
        super("no order with id " + orderId);
    }
}
