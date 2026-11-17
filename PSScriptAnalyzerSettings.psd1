@{
    # Hanya laporkan temuan berlevel Error dan Warning (abaikan Information).
    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # Toolkit ini adalah CLI interaktif; Write-Host berwarna memang disengaja.
        'PSAvoidUsingWriteHost'

        # Fungsi menu (Add-Check, Write-Ok, dsb.) tidak mengubah state sistem,
        # jadi tidak perlu mendukung -ShouldProcess.
        'PSUseShouldProcessForStateChangingFunctions'

        # Nama seperti Get-LocalPrinterNames / Read-YesNo lebih jelas dalam bentuk jamak.
        'PSUseSingularNouns'

        # Nama fungsi menu memakai kata yang deskriptif (mis. Pause-Menu).
        'PSUseApprovedVerbs'

        # Windows 7 hanya punya WMI (Get-WmiObject); CIM tidak tersedia di PS 2.0.
        'PSAvoidUsingWMICmdlet'

        # Blok catch kosong dipakai sengaja untuk operasi best-effort
        # (mis. menutup koneksi, menghentikan transcript) yang boleh gagal.
        'PSAvoidUsingEmptyCatchBlock'

        # Sering salah deteksi karena parameter dipakai lewat splatting/dinamis.
        'PSReviewUnusedParameter'

        # ShouldProcess ditangani di level script (SupportsShouldProcess),
        # bukan di setiap fungsi internal.
        'PSShouldProcess'
    )
}
