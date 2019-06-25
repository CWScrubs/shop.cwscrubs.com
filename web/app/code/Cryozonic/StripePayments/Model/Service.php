<?php

namespace Cryozonic\StripePayments\Model;

use Cryozonic\StripePayments\Api\ServiceInterface;
use Cryozonic\StripePayments\Helper\Logger;

class Service implements ServiceInterface
{
    /**
     * @var \Magento\Checkout\Helper\Data
     */
    private $checkoutHelper;

    /**
     * Constructor
     * @param \Magento\Checkout\Helper\Data $checkoutHelper
     */
    public function __construct(
        \Magento\Checkout\Helper\Data $checkoutHelper,
        \Cryozonic\StripePayments\Helper\Generic $helper,
        \Cryozonic\StripePayments\Model\PaymentIntent $paymentIntent
    ) {
        $this->checkoutHelper = $checkoutHelper;
        $this->paymentIntent = $paymentIntent;
        $this->helper = $helper;
    }

	/**
	 * Return URL
	 * @return string
	 */
    public function redirect_url()
    {
        return null;
    }

    /**
     * Refunds any dangling PIs for the order and creates a new one for the checkout session
     *
     * @api
     * @return mixed Json object containing the new PI ID.
     */
    public function reset_payment_intent($status, $response)
    {
        if ($this->paymentIntent->isSuccessful() && !$this->paymentIntent->getDescription())
        {
            $quoteId = $this->helper->getQuote()->getId();
            $this->paymentIntent->fullRefund("duplicate", ["Status" => $status, "Response" => $response]);
            $this->paymentIntent->destroy($quoteId);
            $this->paymentIntent->create();
        }

        $clientSecret = $this->paymentIntent->getClientSecret();

        return \Zend_Json::encode([
            "paymentIntent" => $clientSecret
        ]);
    }

    public function payment_intent_refresh()
    {
        // We simply need to invalidate the local cache so that we don't try to update successful PIs
        $this->paymentIntent->isSuccessful();
        return \Zend_Json::encode([]);
    }
}
