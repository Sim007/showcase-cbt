package cbt.payment;

import org.springframework.data.jpa.repository.JpaRepository;

/** Eigen database, geen gedeelde opslag met Order. */
public interface PaymentRepository extends JpaRepository<PaymentEntity, String> {
}
