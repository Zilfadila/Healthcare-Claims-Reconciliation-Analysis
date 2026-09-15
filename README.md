**Healthcare Claims Reconciliation Analysis** (English)

1. Project Overview

This project performs an end-to-end reconciliation of healthcare insurance claims data, checking whether the reimbursement totals reported at the beneficiary level actually match the sum of their individual claims. Built using SQL for data processing and Excel for the reporting layer, matching the tool combination commonly required for analytics/reporting roles in the insurance sector.

2. Objectives

* Determine whether reported reimbursement totals match calculated totals from individual claims, for both inpatient and outpatient claims.
* Investigate the root cause of any mismatches through systematic hypothesis testing, rather than assuming a single explanation.
* Flag providers whose average claim value significantly exceeds the norm, for review purposes.
* Produce a reporting layer (Excel dashboard) that traces every number back to its source.

3. Dataset

* Source: Kaggle - "Healthcare Provider Fraud Detection Analysis" (public dataset)
* Tables: Beneficiary, Inpatient, Outpatient
* Scale: 138,556 beneficiaries, 5,411 providers
* Table combination logic: Inpatient and Outpatient are combined via UNION ALL into a single `all_claims` table (since both represent individual claim records with similar structure). Beneficiary is joined separately, since it holds the reported total being compared against - not claims data to be unioned.

4. Methodology

The SQL script is organized into 6 sections:
* Setup - building the `all_claims` table via UNION ALL.
* Validation - 5 structural checks: duplicate ClaimID, orphan BeneID, negative/null values, illogical claim dates, discharge date before admission date.
* Reconciliation (Inpatient) - comparing reported vs. calculated totals.
* Reconciliation (Outpatient) - same comparison, separate claim type.
* Root Cause Investigation - systematic hypothesis testing for mismatch patterns.
* Reporting - provider summary and monthly trend queries feeding the Excel dashboard.

5. Key Findings

**Inpatient Claims**
* 86.3% match rate (119,589 of 138,556 matched).
* 99.8% of mismatches showed reported > calculated. Manual sampling of individual beneficiaries confirmed the pattern was consistent with the training extract being a subset of a more complete source system - not a processing error, though the exact source-side mechanism could not be verified further.
* The remaining 0.2% (43 cases) showed calculated > reported. A self-join query matching BeneID + ClaimStartDt + Provider (with differing ClaimID) explained 37 of these 43 cases - consistent with revised/overlapping claims where the original record wasn't removed.

**Outpatient Claims**
* 63.3% match rate (87,730 of 138,556 matched) - lower than inpatient.
* The majority mismatch pattern matched the inpatient explanation above.
* A minority of 1,023 cases showed a different pattern. Three hypotheses were tested and disproven: wrong column reference (ruled out via schema check), the same overlapping-claims pattern as inpatient (dates/providers did not match), and zero-value claims skewing totals (excluding them did not change the result). This was documented as an open question rather than forcing an unverified conclusion.

**Provider-Level Review**
* Providers flagged for review when average claim value exceeds 1.5x the overall average.
* 965 of 5,411 providers flagged.

6. Business Recommendations

* Prioritize investigation of the 965 flagged providers, starting with those showing the largest deviation from the average.
* Escalate the 1,023 unexplained outpatient cases to a team with access to the original source system (beyond this training extract) for further investigation.
* Treat the inpatient/outpatient match rate gap (86.3% vs 63.3%) as a signal to review outpatient data completeness specifically, rather than assuming both claim types share identical data quality.

7. Tech Stack

* SQL: PostgreSQL (via DBeaver)
* Reporting: Excel (formula-based tables, native charts, dashboard with KPI cards)

---

**Analisis Rekonsiliasi Data Klaim Kesehatan** (Indonesia)

1. Project Overview

Project ini melakukan rekonsiliasi end-to-end terhadap data klaim asuransi kesehatan, memeriksa apakah total reimbursement yang dilaporkan di level beneficiary benar-benar sesuai dengan hasil penjumlahan klaim individualnya. Dibangun menggunakan SQL untuk pemrosesan data dan Excel untuk lapisan pelaporan, sesuai kombinasi tools yang umum dibutuhkan untuk role analytics/reporting di sektor asuransi.

2. Objectives

* Menentukan apakah total reimbursement yang dilaporkan sesuai dengan total hasil kalkulasi dari klaim individual, baik untuk klaim inpatient maupun outpatient.
* Menyelidiki akar penyebab mismatch lewat pengujian hipotesis sistematis, bukan asal mengasumsikan satu penjelasan.
* Menandai provider yang rata-rata nilai klaimnya jauh melebihi normal, untuk keperluan review.
* Menghasilkan lapisan pelaporan (dashboard Excel) yang setiap angkanya bisa ditelusuri kembali ke sumbernya.

3. Dataset

* Sumber: Kaggle - "Healthcare Provider Fraud Detection Analysis" (dataset publik)
* Tabel: Beneficiary, Inpatient, Outpatient
* Skala: 138.556 beneficiary, 5.411 provider
* Logika penggabungan tabel: Inpatient dan Outpatient digabung lewat UNION ALL jadi satu tabel `all_claims` (karena keduanya sama-sama merepresentasikan record klaim individual dengan struktur mirip). Beneficiary di-JOIN terpisah, karena berisi total yang dilaporkan yang jadi pembanding - bukan data klaim yang perlu di-union.

4. Methodology

Script SQL disusun jadi 6 bagian:
* Setup - membangun tabel `all_claims` lewat UNION ALL.
* Validation - 5 pengecekan struktural: duplicate ClaimID, orphan BeneID, nilai negatif/null, tanggal klaim tidak logis, tanggal discharge sebelum admission.
* Reconciliation (Inpatient) - membandingkan total reported vs calculated.
* Reconciliation (Outpatient) - perbandingan serupa, jenis klaim terpisah.
* Root Cause Investigation - pengujian hipotesis sistematis untuk pola mismatch.
* Reporting - query provider summary dan tren bulanan yang menjadi input dashboard Excel.

5. Key Findings

**Klaim Inpatient**
* Match rate 86.3% (119.589 dari 138.556 cocok).
* 99.8% dari mismatch menunjukkan reported > calculated. Sampling manual ke beberapa beneficiary mengonfirmasi pola ini konsisten dengan extract training yang merupakan subset dari sumber yang lebih lengkap - bukan kesalahan proses, meski mekanisme pasti di sisi sumber tidak bisa diverifikasi lebih lanjut.
* Sisanya 0.2% (43 kasus) menunjukkan calculated > reported. Query self-join yang mencocokkan BeneID + ClaimStartDt + Provider (dengan ClaimID berbeda) menjelaskan 37 dari 43 kasus ini - konsisten dengan klaim yang direvisi/overlap dimana record asli tidak terhapus.

**Klaim Outpatient**
* Match rate 63.3% (87.730 dari 138.556 cocok) - lebih rendah dari inpatient.
* Pola mismatch mayoritas sesuai dengan penjelasan inpatient di atas.
* Minoritas 1.023 kasus menunjukkan pola berbeda. Tiga hipotesis diuji dan terbukti salah: kolom yang salah rujuk (tersingkir lewat cek skema), pola overlapping claims yang sama seperti inpatient (tanggal/provider tidak cocok), dan klaim bernilai nol yang mendistorsi total (dikecualikan pun hasil tidak berubah). Ini didokumentasikan sebagai open question, bukan memaksakan kesimpulan yang belum terverifikasi.

**Provider-Level Review**
* Provider ditandai untuk review kalau rata-rata nilai klaimnya melebihi 1.5x rata-rata keseluruhan.
* 965 dari 5.411 provider ter-flag.

6. Business Recommendations

* Prioritaskan investigasi ke 965 provider yang ter-flag, mulai dari yang deviasinya paling besar.
* Eskalasi 1.023 kasus outpatient yang belum terjelaskan ke tim yang punya akses ke sistem sumber asli (di luar extract training ini) untuk investigasi lebih lanjut.
* Perlakukan gap match rate inpatient/outpatient (86.3% vs 63.3%) sebagai sinyal untuk mereview kelengkapan data outpatient secara spesifik, bukan asumsi bahwa kedua jenis klaim punya kualitas data yang sama.

7. Tech Stack

* SQL: PostgreSQL (via DBeaver)
* Reporting: Excel (tabel berbasis formula, chart native, dashboard dengan KPI card)
