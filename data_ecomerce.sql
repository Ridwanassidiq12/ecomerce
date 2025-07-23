#BUAT SCHEMA DB
CREATE SCHEMA Ecomerce_Sql_Analysis; 

#PANGGIL DB YANG TADI DI BUAT
USE Ecomerce_Sql_Analysis;
SHOW TABLES;

# BUAT TABLE ecomerce_transaksi
CREATE TABLE ecomerce_transaksi (
    Transaction_ID INT PRIMARY KEY,
    Customer_ID VARCHAR(200),
    Customer_Name VARCHAR(200),
    Product_ID VARCHAR(200),
    Product_Name VARCHAR(200),
    Category VARCHAR(50),
    Unit_Price INT,
    Quantity INT,
    Order_Date DATE,
    Payment_Method VARCHAR(50),
    Shipping_Courier VARCHAR(50),
    Shipping_Time_Days INT,
    Review_Score INT,
    Review_Comment TEXT,
    Total_Amount INT
);

# PANGGIL TABLE YANG TADI DIBUAT
SELECT * FROM ecomerce_transaksi;

# Mengubah type data
ALTER TABLE ecomerce_transaksi
MODIFY Transaction_ID VARCHAR(200);

# IMPORT DATANYA DARI FILE YANG DI DOWNLOAD DARI KAGLE
#sebelum mengimport kita lihat 'secure_file_priv' ini untuk menaruh data yg direkomendasikan sql agar saat import data aman
SHOW VARIABLES LIKE 'secure_file_priv';
#lalu pindahkan file sales_car.csv di folder C:\ProgramData\MySQL\MySQL Server 8.0\Uploads\sales_car.csv

LOAD DATA INFILE "C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Ecommerce_SQL_Analysis.csv"
INTO TABLE ecomerce_transaksi
FIELDS TERMINATED BY ',' # menandakan bahwa setiap column di file csv dipisahkan coma
ENCLOSED BY '"' # menunjukan bahwa setiap nilai di dalam column di bungkus "" cth: "KIA"
LINES TERMINATED BY '\n' #menujukan bahwa setiap baris di file csv dipisahkan oleh newline \n
IGNORE 1 ROWS; #mengabaikan baris pertama karena file csv baris pertama itu nama column

SELECT * FROM ecomerce_transaksi;


 # 1. Ambil 5 produk (Product_Name) dengan total pendapatan (Total_Amount) tertinggi.
with top_5 AS (
		SELECT Product_Name, SUM(Total_Amount)  as jumlah_product_top_5
        FROM ecomerce_transaksi
        GROUP BY Product_Name
        ORDER BY jumlah_product_top_5 DESC
        LIMIT 5 
)
SELECT * FROM top_5;

# 2.  Tampilkan kurir (Shipping_Courier) dengan rata-rata Shipping_Time_Days paling tinggi dan paling rendah. Urutkan.
# paling tinggi
with top AS (
		SELECT Shipping_Courier, AVG(Shipping_Time_Days)  as avg_kurir_top
        FROM ecomerce_transaksi
        GROUP BY Shipping_Courier
        ORDER BY avg_kurir_top DESC
)
SELECT * FROM top;

# paling rendah
with low AS (
		SELECT Shipping_Courier, AVG(Shipping_Time_Days)  as avg_kurir_low
        FROM ecomerce_transaksi
        GROUP BY Shipping_Courier
        ORDER BY avg_kurir_low ASC
)
SELECT * FROM low;

 # 3. Hitung jumlah transaksi berdasarkan kombinasi Review_Score dan Review_Comment. Urutkan dari komentar paling sering muncul pada skor rendah.
WITH review AS (
    SELECT Review_Comment,Review_Score, COUNT(*) AS jumlah_review
    FROM ecomerce_transaksi
    GROUP BY Review_Comment, Review_Score
)
SELECT * FROM review
ORDER BY Review_Score ASC, jumlah_review DESC;

# 4. Hitung total pendapatan untuk masing-masing Payment_Method. Berapa % kontribusi tiap metode terhadap pendapatan total?
WITH payment AS (
    SELECT Payment_Method, SUM(Total_Amount) AS jumlah_payment_method
    FROM ecomerce_transaksi
    GROUP BY Payment_Method
    ORDER BY jumlah_payment_method
),

total_amount AS (
	SELECT SUM(Total_Amount) AS jumlah_total_amount
    FROM ecomerce_transaksi
)
SELECT 
    p.Payment_Method,
    p.jumlah_payment_method,
    t.jumlah_total_amount,
    ROUND((p.jumlah_payment_method / t.jumlah_total_amount) * 100, 2) AS persen_kontribusi
FROM payment p
CROSS JOIN total_amount t
ORDER BY persen_kontribusi DESC;

# 5.  Siapa saja customer (Customer_ID) yang melakukan transaksi lebih dari 3 kali? Sertakan total pembelian mereka.
with customer AS (
		SELECT Customer_ID, COUNT(*) as jumlah_transaksi, SUM(Total_Amount)  as jumlah_Total_Amount
        FROM ecomerce_transaksi
        GROUP BY Customer_ID
        HAVING jumlah_transaksi > 3
)
SELECT * FROM customer
ORDER BY jumlah_transaksi ASC;

# 6.  Produk mana saja (Product_Name) yang memiliki total Quantity terjual lebih dari 50 unit? Urutkan dari tertinggi.
with product AS (
		SELECT Product_Name, COUNT(*) as jumlah_product, SUM(Quantity)  as total_qty
        FROM ecomerce_transaksi
        GROUP BY Product_Name
        HAVING total_qty > 50
)
SELECT * FROM product
ORDER BY total_qty DESC;

# 7.  Tampilkan transaksi yang memiliki Review_Score ≤ 2 tapi komentar mengandung kata positif seperti “great”, “excellent”, atau “fast”.
SELECT Review_Score, Review_Comment FROM ecomerce_transaksi
WHERE Review_Score <= 2
AND (
	LOWER(Review_Comment) LIKE '%great%' OR
	LOWER(Review_Comment) LIKE '%excellent%' OR
	LOWER(Review_Comment) LIKE '%fast%'
);

# 8. Apakah produk dengan review bagus juga mendatangkan pendapatan tertinggi? Bandingkan pendapatan rata-rata dari produk dengan skor review ≥ 4 dan ≤ 2
# Insight: Apakah rating selalu berkorelasi dengan revenue?
SELECT Review_Score, SUM(Total_Amount) as jumlah_pendapatan 
FROM ecomerce_transaksi
GROUP BY Review_Score
HAVING Review_Score <= 2;

SELECT Review_Score, SUM(Total_Amount) as jumlah_pendapatan 
FROM ecomerce_transaksi
GROUP BY Review_Score
HAVING Review_Score >= 4;

SELECT 
    CASE 
        WHEN Review_Score >= 4 THEN 'Bagus (≥ 4)'
        WHEN Review_Score <= 2 THEN 'Jelek (≤ 2)'
        ELSE 'Lainnya'
    END AS kategori_score_review,
    ROUND(AVG(Total_Amount), 2) AS avg_total_pendapatan
FROM ecomerce_transaksi
WHERE Review_Score >= 4 OR Review_Score <= 2
GROUP BY kategori_score_review;
    
# 9. Kurir mana yang berisiko membuat pelanggan kecewa?
#Dari hasil waktu pengiriman dan skor review, kurir mana yang perlu dievaluasi?
#Insight: Hubungkan performa kurir dengan penilaian pelanggan.

SELECT 
    CASE 
        WHEN Review_Score <= 2 THEN 'Jelek (≤ 2)'
        ELSE 'Lainnya'
    END AS kategori_score_review,
    Shipping_Courier, COUNT(*) as kurir,
    ROUND(AVG(Shipping_Time_Days), 2) AS avg_total_waktu_pengiriman
FROM ecomerce_transaksi
WHERE Review_Score <= 2
GROUP BY kategori_score_review, Shipping_Courier;

SELECT 
    CASE 
        WHEN Review_Score >= 4 THEN 'Bagus (≥ 4)'
        ELSE 'Lainnya'
    END AS kategori_score_review,
    Shipping_Courier, COUNT(*) as kurir,
    ROUND(AVG(Shipping_Time_Days), 2) AS avg_total_waktu_pengiriman
FROM ecomerce_transaksi
WHERE Review_Score >= 4
GROUP BY kategori_score_review, Shipping_Courier;

# 10.  Apakah perlu meningkatkan stok untuk produk tertentu?
# Dari simulasi restock:
# - Produk mana saja yang paling banyak diminta?
# - Apakah review terhadap produk tersebut juga positif?

with product AS (
		SELECT Product_Name, SUM(Quantity) as jumlah_qty , AVG(Review_Score)  as review_score_avg, SUM(Review_Score)  as review_score_total
        FROM ecomerce_transaksi
        GROUP BY Product_Name
        ORDER BY jumlah_qty DESC
)
SELECT * FROM product;


#11.   Segmentasi Pelanggan Loyal
# Dari customer repeat buyer:
# - Berapa kontribusi total pendapatan dari pelanggan yang berulang?
# - Perlu ada loyalty program

with customer AS (
		SELECT Customer_Name, COUNT(*) as jumlah_transaksi , SUM(Total_Amount)  as jumlah_total_amount
        FROM ecomerce_transaksi
        GROUP BY Customer_Name
        ORDER BY jumlah_transaksi DESC
),
total_amount AS (
	SELECT SUM(Total_Amount) AS jumlah_total_amount
    FROM ecomerce_transaksi
)
SELECT 
    c.Customer_Name,
    c.jumlah_total_amount,
    t.jumlah_total_amount,
    ROUND((c.jumlah_total_amount / t.jumlah_total_amount) * 100, 2) AS persen_kontribusi
FROM customer c
CROSS JOIN total_amount t
ORDER BY persen_kontribusi DESC;

# 12. Review Anomali – Peluang atau Masalah?
# Temukan review yang komentarnya positif tapi rating rendah.
# Insight: Apakah ini bug sistem, pelanggan salah input, atau hal lain yang perlu ditindaklanjuti?

SELECT Review_Score, Review_Comment  FROM ecomerce_transaksi
WHERE Review_Score <= 3
AND (
	LOWER(Review_Comment) LIKE '%great%' OR
	LOWER(Review_Comment) LIKE '%excellent%' OR
	LOWER(Review_Comment) LIKE '%fast%'
);

SELECT COUNT(*) AS jumlah_anomali
FROM ecomerce_transaksi
WHERE Review_Score <= 3
AND (
    LOWER(Review_Comment) LIKE '%great%' OR
    LOWER(Review_Comment) LIKE '%excellent%' OR
    LOWER(Review_Comment) LIKE '%fast%'
);
SELECT COUNT(*) AS total_transaksi
FROM ecomerce_transaksi;

# 13.   Metode Pembayaran Mana yang Harus Didorong?
# Dari distribusi pendapatan per payment method, apakah perlu promosi metode tertentu seperti e-wallet?

WITH payment AS (
    SELECT Payment_Method, SUM(Total_Amount) AS jumlah_payment_method
    FROM ecomerce_transaksi
    GROUP BY Payment_Method
    ORDER BY jumlah_payment_method DESC
)
SELECT * FROM payment;

