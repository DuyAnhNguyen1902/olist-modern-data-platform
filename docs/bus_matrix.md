# Kimball Bus Matrix

Bus matrix xác định business process (fact) và các conformed dimensions được dùng chung.

| Business process | Date | Customer | Product | Seller | Payment method | Order status |
|---|---:|---:|---:|---:|---:|---:|
| Order items | ✓ | ✓ | ✓ | ✓ |  |  |
| Payments | ✓ | ✓ |  |  | thuộc tính fact |  |
| Order lifecycle | nhiều vai trò | ✓ |  |  |  | thuộc tính fact |
| Customer events *(về sau)* | ✓ | ✓ | ✓ |  |  |  |

## Grain

- `fact_order_items`: một dòng cho một item sequence trong một order.
- `fact_payments`: một dòng cho một payment sequence trong một order.
- `fact_order_lifecycle`: một dòng cho một order.
- `fact_customer_events` *(về sau)*: một dòng cho một event.

Không join trực tiếp `fact_order_items` với `fact_payments` để tính doanh thu. Hai bảng đều
có quan hệ nhiều-dòng-trên-một-order, nên join như vậy sẽ tạo fan-out.

