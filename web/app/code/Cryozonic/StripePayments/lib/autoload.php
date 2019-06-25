<?php

$filename = __DIR__ . "/stripe-php/init.php";

// The Stripe class should exist if the Stripe PHP library has been installed with composer.
// If it hasn't been installed, include the local copy of the library.
// WARNING: Including the local copy breaks compilation
if (!class_exists('\Stripe\Stripe') && file_exists($filename))
    require_once $filename;

if (!class_exists('\Stripe\Stripe'))
    throw new \Exception("The Stripe PHP library is not installed. See http://store.cryozonic.com/documentation/magento-2-stripe-payments for details.");

\Stripe\Stripe::setApiVersion("2018-01-23");
\Stripe\Stripe::setAppInfo("Stripe Payments M2", "2.5.0", "https://store.cryozonic.com/magento-2/stripe-payments.html");
