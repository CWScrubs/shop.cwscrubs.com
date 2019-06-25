<?php

namespace Cryozonic\StripePayments\Observer;

use Magento\Framework\Event\Observer;
use Magento\Framework\Event\ObserverInterface;
use Cryozonic\StripePayments\Helper\Logger;

class QuoteObserver implements ObserverInterface
{
    public function __construct(\Cryozonic\StripePayments\Model\PaymentIntent $paymentIntent)
    {
        $this->paymentIntent = $paymentIntent;
    }

    /**
     * @param Observer $observer
     * @return void
     */
    public function execute(Observer $observer)
    {
        $quote = $observer->getEvent()->getQuote();
        $this->paymentIntent->updateFrom($quote);
    }
}
