# Data Model

## Source

Olist cung cấp dữ liệu đơn hàng, khách hàng, sản phẩm, seller, payment, review và geolocation.
Các raw table lưu tất cả giá trị nguồn dưới dạng text để tránh mất dữ liệu khi ép kiểu.

## Layers

```text
raw         Bản sao gần nguyên trạng của source + load metadata
staging     Chuẩn hóa tên, kiểu dữ liệu và giá trị rỗng
warehouse   Kimball dimensions và facts cho analytics
audit       Load history và data quality results
```

## Star schemas

```text
dim_date -----------+
dim_customer -------+--> fact_order_items <-- dim_product
dim_seller ---------+             |
                                  +-- order_id (degenerate dimension)

dim_date -----------+
dim_customer -------+--> fact_payments

dim_date (role playing) --+
dim_customer -------------+--> fact_order_lifecycle
```

`dim_date` đóng nhiều vai trò: purchase date, approval date, delivered date và estimated
delivery date.

## Customer grain

Trong Olist, `customer_id` là khóa của customer record gắn với một order;
`customer_unique_id` nhận diện người mua qua nhiều order. Phiên bản đầu dùng `customer_id`
làm natural key của dimension và giữ `customer_unique_id` làm thuộc tính phục vụ repeat-customer
analysis. Khi nguồn giả lập có lịch sử thay đổi địa chỉ, dimension sẽ được nâng cấp lên SCD Type 2.

## Unknown member

Customer, product và seller dimension có member `-1/UNKNOWN`. Late-arriving dimension hoặc
khóa nguồn chưa tồn tại sẽ trỏ đến member này thay vì tạo foreign key null. Data quality check
cảnh báo khi tỷ lệ unknown vượt 1%.

