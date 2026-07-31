package cbt.order;

import org.springframework.data.jpa.repository.JpaRepository;

/** Eigen database, geen gedeelde opslag met Payment. */
public interface OrderRepository extends JpaRepository<OrderEntity, String> {
}
