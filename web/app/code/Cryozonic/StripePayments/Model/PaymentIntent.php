<?php

namespace Cryozonic\StripePayments\Model;

use Magento\Framework\Validator\Exception;
use Magento\Framework\Exception\LocalizedException;
use Cryozonic\StripePayments\Helper\Logger;

class PaymentIntent
{
    public $paymentIntent = null;
    public $params = [];
    public $stopUpdatesForThisSession = false;
    public $quote = null; // Overwrites default quote
    public $capture = null; // Overwrites default capture method

    const CAPTURED = "succeeded";
    const AUTHORIZED = "requires_capture";
    const CAPTURE_METHOD_MANUAL = "manual";
    const CAPTURE_METHOD_AUTOMATIC = "automatic";
    const REQUIRES_ACTION = "requires_action";
    const NewPIAPIVersion = "2019-02-19";
    const OldPIAPIVersion = "2018-01-23";

    public function __construct(
        \Cryozonic\StripePayments\Helper\Generic $helper,
        \Magento\Framework\App\CacheInterface $cache,
        \Cryozonic\StripePayments\Helper\Serializer $serializer,
        \Cryozonic\StripePayments\Model\Config $config,
        \Cryozonic\StripePayments\Model\StripeCustomer $customer,
        \Magento\Customer\Model\AddressFactory $addressFactory,
        \Magento\Quote\Model\QuoteFactory $quoteFactory,
        \Magento\Framework\Event\ManagerInterface $eventManager
        )
    {
        $this->helper = $helper;
        $this->cache = $cache;
        $this->serializer = $serializer;
        $this->config = $config;
        $this->customer = $customer;
        $this->quoteFactory = $quoteFactory;
        $this->addressFactory = $addressFactory;
        $this->eventManager = $eventManager;
    }

    // If we already created any payment intents for this quote, load them
    public function loadFromCache($quote)
    {
        if (empty($quote))
            return null;

        $quoteId = $quote->getId();
        if (empty($quoteId))
            $quoteId = $quote->getQuoteId(); // Admin order quotes

        if (empty($quoteId))
            return null;

        $object = $this->cache->load('payment_intent_' . $quoteId);
        if (!empty($object))
        {
            $this->paymentIntent = $this->serializer->unserialize($object);
        }
        else
            return null;

        // Was the cached object unserialized with a wrong class type?
        // Ambiguous instructions on how to reproduce
        if (!($this->paymentIntent instanceof \Stripe\PaymentIntent))
            $this->refreshCache($quoteId);

        // We want to invalidate the object from the cache if the Payment Action has changed
        if ($this->hasPaymentActionChanged())
        {
            $this->paymentIntent->cancel();
            $this->paymentIntent = null;
            $this->cache->remove('payment_intent_' . $quoteId);
        }

        return $this->paymentIntent;
    }

    protected function hasPaymentActionChanged()
    {
        $captureMethod = $this->getCaptureMethod();

        return ($captureMethod != $this->paymentIntent->capture_method);
    }

    protected function useNewAPIVersion()
    {
        \Stripe\Stripe::setApiVersion(PaymentIntent::NewPIAPIVersion);
    }

    protected function revertAPIVersion()
    {
        \Stripe\Stripe::setApiVersion(PaymentIntent::OldPIAPIVersion);
    }

    public function create($quote = null)
    {
        if (!$this->shouldUsePaymentIntents())
            return $this;

        if (empty($quote))
            $quote = $this->getQuote();

        // We don't want to be creating a payment intent if there is no cart/quote
        if (!$quote)
        {
            $this->paymentIntent = null;
            return $this;
        }

        $this->useNewAPIVersion();

        $this->loadFromCache($quote);

        $this->getParamsFrom($quote);
        if ($this->params['amount'] <= 0)
        {
            $this->destroy($quote->getId(), true);
            return $this;
        }

        if ($this->paymentIntent && !$this->differentFrom($quote))
        {
            // Logger::log("They are the same");
        }
        else if ($this->paymentIntent && $this->differentFrom($quote))
        {
            $this->updateFrom($quote);
        }
        else
        {
            $this->getParamsFrom($quote);
            $this->paymentIntent = \Stripe\PaymentIntent::create($this->params);
            $this->updateCache($quote->getId());
        }

        $this->revertAPIVersion();
        return $this;
    }

    protected function updateCache($quoteId)
    {
        $key = 'payment_intent_' . $quoteId;
        $data = $this->serializer->serialize($this->paymentIntent);
        $tags = ['cryozonic_stripe_payment_intents'];
        $lifetime = 12 * 60 * 60; // 12 hours
        $this->cache->save($data, $key, $tags, $lifetime);
    }

    protected function getParamsFrom($quote)
    {
        if ($this->config->useStoreCurrency())
        {
            $amount = $quote->getGrandTotal();
            $currency = $quote->getQuoteCurrencyCode();
        }
        else
        {
            $amount = $quote->getBaseGrandTotal();
            $currency = $quote->getBaseCurrencyCode();
        }

        $cents = 100;
        if ($this->helper->isZeroDecimal($currency))
            $cents = 1;

        $this->params['amount'] = round($amount * $cents);
        $this->params['currency'] = strtolower($currency);
        $this->params['capture_method'] = $this->getCaptureMethod();
        $this->params["payment_method_types"] = ["card"]; // For now
        $this->params['confirmation_method'] = 'manual';

        $this->adjustAmountForSubscriptions();

        $statementDescriptor = $this->config->getStatementDescriptor();
        if (!empty($statementDescriptor))
            $this->params["statement_descriptor"] = $statementDescriptor;
        else
            unset($this->params['statement_descriptor']);

        $shipping = $this->getShippingAddressFrom($quote);
        if ($shipping)
            $this->params['shipping'] = $shipping;
        else
            unset($this->params['shipping']);
    }

    // Adds initial fees, or removes item amounts if there is a trial set
    protected function adjustAmountForSubscriptions()
    {
        $currentApiVersion = \Stripe\Stripe::getApiVersion();
        $this->revertAPIVersion();

        $cents = 100;
        if ($this->helper->isZeroDecimal($this->params['currency']))
            $cents = 1;

        $returnData = new \Magento\Framework\DataObject();
        $returnData->setAmount($this->params['amount']);
        $returnData->setParams($this->params);
        $returnData->setCents($cents);
        $returnData->setIsDryRun(true);

        $this->eventManager->dispatch('cryozonic_create_subscriptions', array(
            'order' => $this->getQuote(),
            'returnData' => $returnData
        ));

        $this->params = $returnData->getParams();

        \Stripe\Stripe::setApiVersion($currentApiVersion);
    }

    // Returns true if we have already created a paymentIntent with these parameters
    protected function alreadyCreated($amount, $currency, $methods)
    {
        return (!empty($this->paymentIntent) &&
            $this->paymentIntent->amount == $amount &&
            $this->paymentIntent->currency == $currency &&
            $this->samePaymentMethods($methods)
            );
    }

    // Checks if the payment methods in the parameter are the same with the payment methods on $this->paymentMethods
    protected function samePaymentMethods($methods)
    {
        $currentMethods = $this->paymentIntent->payment_method_types;
        return (empty(array_diff($methods, $currentMethods)) &&
            empty(array_diff($currentMethods, $methods)));
    }

    public function getClientSecret()
    {
        if (empty($this->paymentIntent))
            return null;

        if (!$this->shouldUsePaymentIntents())
            return null;

        return $this->paymentIntent->client_secret;
    }

    public function getStatus()
    {
        if (empty($this->paymentIntent))
            return null;

        if (!$this->shouldUsePaymentIntents())
            return null;

        return $this->paymentIntent->status;
    }

    public function getPaymentIntentID()
    {
        if (empty($this->paymentIntent))
            return null;

        return $this->paymentIntent->id;
    }

    protected function getQuote()
    {
        // Capturing an expired authorization
        if ($this->quote)
            return $this->quote;

        // Admin area new order page
        if ($this->helper->isAdmin())
        {
            $quoteId = $this->helper->getBackendSessionQuote()->getQuoteId();
            $quote = $this->quoteFactory->create()->load($quoteId);
            return $quote;
        }

        // Front end checkout
        return $this->helper->getSessionQuote();
    }

    public function updateFrom($quote)
    {
        if (empty($quote))
            return $this;

        if (!$this->shouldUsePaymentIntents())
            return $this;

        if ($this->stopUpdatesForThisSession)
            return $this;

        $this->useNewAPIVersion();

        $this->loadFromCache($quote);

        if ($this->isSuccessful(false))
            return $this;

        if (!$this->paymentIntent)
            return $this;

        $this->getParamsFrom($quote);
        if ($this->params['amount'] <= 0)
        {
            $this->destroy($quote->getId(), true);
            return $this;
        }

        if ($this->differentFrom($quote))
        {
            $params = $this->getFilteredParamsForUpdate();

            foreach ($params as $key => $value)
                $this->paymentIntent->{$key} = $value;

            $this->updatePaymentIntent($quote);
        }

        $this->revertAPIVersion();
    }

    // Performs an API update of the PI
    public function updatePaymentIntent($quote)
    {
        try
        {
            $this->paymentIntent->save();
            $this->updateCache($quote->getId());
        }
        catch (\Exception $e)
        {
            $this->log($e);
            throw $e;
        }
    }

    protected function log($e)
    {
        Logger::log("Payment Intents Error: " . $e->getMessage());
        Logger::log("Payment Intents Error: " . $e->getTraceAsString());
    }

    public function destroy($quoteId, $cancelPaymentIntent = false)
    {
        $this->cache->remove('payment_intent_' . $quoteId);

        if ($this->paymentIntent && $cancelPaymentIntent)
            $this->paymentIntent->cancel();

        $this->paymentIntent = null;
        $this->params = [];
    }

    public function fullRefund($reason = "duplicate", $metadata = null)
    {
        if (empty($this->paymentIntent))
            throw new \Exception("The payment intent is not loaded");

        foreach ($this->paymentIntent->charges->data as $charge)
        {
            $params = [
              "charge" => $charge->id,
            ];

            if (!empty($reason))
                $params["reason"] = $reason;

            if (!empty($metadata))
                $params["metadata"] = $metadata;

            $re = \Stripe\Refund::create($params);
        }
    }

    // At the final place order step, if the amount and currency has not changed, Magento will not call
    // the quote observer. But the customer may have changed the shipping address, in which case a
    // payment intent update is needed. We want to unset the amount and currency in this case because
    // the Stripe API will throw an error, because the PI has already been authorized at the checkout
    protected function getFilteredParamsForUpdate()
    {
        $params = $this->params; // clones the array
        $allowedParams = ["amount", "currency", "description", "metadata", "shipping"];

        foreach ($params as $key => $value) {
            if (!in_array($key, $allowedParams))
                unset($params[$key]);
        }

        if ($params["amount"] == $this->paymentIntent->amount)
            unset($params["amount"]);

        if ($params["currency"] == $this->paymentIntent->currency)
            unset($params["currency"]);

        if (empty($params["shipping"]))
            $params["shipping"] = null; // Unsets it through the API

        return $params;
    }

    public function differentFrom($quote)
    {
        $isAmountDifferent = ($this->paymentIntent->amount != $this->params['amount']);
        $isCurrencyDifferent = ($this->paymentIntent->currency != $this->params['currency']);
        $isPaymentMethodDifferent = !$this->samePaymentMethods($this->params['payment_method_types']);
        $isAddressDifferent = $this->isAddressDifferentFrom($quote);

        return ($isAmountDifferent || $isCurrencyDifferent || $isPaymentMethodDifferent || $isAddressDifferent);
    }

    public function isAddressDifferentFrom($quote)
    {
        $newShipping = $this->getShippingAddressFrom($quote);

        // If both are empty, they are the same
        if (empty($this->paymentIntent->shipping) && empty($newShipping))
            return false;

        // If one of them is empty, they are different
        if (empty($this->paymentIntent->shipping) && !empty($newShipping))
            return true;

        if (!empty($this->paymentIntent->shipping) && empty($newShipping))
            return true;

        $comparisonKeys1 = ["name", "phone"];
        $comparisonKeys2 = ["city", "country", "line1", "line2", "postal_code", "state"];

        foreach ($comparisonKeys1 as $key) {
            if ($this->paymentIntent->shipping->{$key} != $newShipping[$key])
                return true;
        }

        foreach ($comparisonKeys2 as $key) {
            if ($this->paymentIntent->shipping->address->{$key} != $newShipping["address"][$key])
                return true;
        }

        return false;
    }

    public function getShippingAddressFrom($quote)
    {
        $address = $quote->getShippingAddress();

        if (empty($quote) || $quote->getIsVirtual())
            return null;

        if (empty($address) || empty($address->getAddressId()))
            return null;

        if (empty($address->getFirstname()))
            $address = $this->addressFactory->create()->load($address->getAddressId());

        if (empty($address->getFirstname()))
            return null;

        $street = $address->getStreet();

        return [
            "address" => [
                "city" => $address->getCity(),
                "country" => $address->getCountryId(),
                "line1" => $street[0],
                "line2" => (!empty($street[1]) ? $street[1] : null),
                "postal_code" => $address->getPostcode(),
                "state" => $address->getRegion()
            ],
            "carrier" => null,
            "name" => $address->getFirstname() . " " . $address->getLastname(),
            "phone" => $address->getTelephone(),
            "tracking_number" => null
        ];
    }

    public function shouldUsePaymentIntents()
    {
        $isModuleEnabled = $this->config->isEnabled();
        // $isStripeJsEnabled = ($this->config->getSecurityMethod() > 0);
        // $hasSubscriptions = $this->helper->hasSubscriptions();
        // $isMultiShipping = $this->helper->isMultiShipping();

        return $isModuleEnabled;
    }

    public function isSuccessful($fetchFromAPI = true)
    {
        if (!$this->shouldUsePaymentIntents())
            return false;

        $quote = $this->getQuote();
        if (!$quote)
            return false;

        $this->loadFromCache($quote);

        if (!$this->paymentIntent)
            return false;

        // Refresh the object from the API
        try
        {
            if ($fetchFromAPI)
                $this->refreshCache($quote->getId());
        }
        catch (\Exception $e)
        {
            return false;
        }

        return $this->isSuccessfulStatus();
    }

    public function isSuccessfulStatus()
    {
        return ($this->paymentIntent->status == PaymentIntent::CAPTURED ||
            $this->paymentIntent->status == PaymentIntent::AUTHORIZED);
    }

    public function refreshCache($quoteId)
    {
        if (!$this->paymentIntent)
            return;

        $this->paymentIntent = \Stripe\PaymentIntent::retrieve($this->paymentIntent->id);

        $key = 'payment_intent_' . $quoteId;
        $data = $this->serializer->serialize($this->paymentIntent);
        $tags = ['cryozonic_stripe_payment_intents'];
        $lifetime = false; // Does not expire
        $this->cache->save($data, $key, $tags, $lifetime);
    }

    public function getCaptureMethod()
    {
        // Overwrite for when capturing an expired authorization
        if ($this->capture)
            return $this->capture;

        if ($this->config->isAuthorizeOnly())
            return PaymentIntent::CAPTURE_METHOD_MANUAL;

        return PaymentIntent::CAPTURE_METHOD_AUTOMATIC;
    }

    public function requiresAction()
    {
        return (
            !empty($this->paymentIntent->status) &&
            ($this->paymentIntent->status == "requires_action" ||
            $this->paymentIntent->status == "requires_source_action")
        );
    }

    protected function adjustForMultishipping($order)
    {
        if (!$this->helper->isMultiShipping())
            return;

        $params = $this->config->getStripeParamsFrom($order);
        $this->paymentIntent->amount = $params['amount'];
        $this->paymentIntent->payment_method = $order->getPayment()->getAdditionalInformation('token');
        $this->updatePaymentIntent($order->getQuote());
    }

    public function confirmAndAssociateWithOrder($order)
    {
        $this->create(); // Load or create the Payment Intent

        if (!$this->paymentIntent)
            throw new LocalizedException(__("Unable to create payment intent"));

        if (!$this->isSuccessful())
        {
            $this->adjustForMultishipping($order);
            $this->paymentIntent->confirm();

            if ($this->requiresAction())
            {
                if ($this->helper->isAdmin())
                {
                    $this->helper->addError("This card cannot be used because it requires a 3D Secure authentication by the customer.");
                    return;
                }

                if ($this->helper->isMultiShipping())
                    throw new LocalizedException(__("This card cannot be used for multi-shipping orders because it requires 3D Secure authentication. Please place your order on its own for this shipping address, or use a different card."));

                throw new \Exception("Authentication Required");
            }

            if (!$this->isSuccessfulStatus())
                throw new LocalizedException(__("Could not confirm payment intent"));
        }

        $params = $this->config->getStripeParamsFrom($order);

        $this->paymentIntent->description = $params['description'];
        $this->paymentIntent->metadata = $params['metadata'];

        $payment = $order->getPayment();
        $payment->setTransactionId($this->paymentIntent->id);
        $payment->setLastTransId($this->paymentIntent->id);
        $payment->setIsTransactionClosed(0);
        $payment->setIsFraudDetected(false);

        $charge = $this->paymentIntent->charges->data[0];

        if ($this->config->isStripeRadarEnabled() &&
            isset($charge->outcome->type) &&
            $charge->outcome->type == 'manual_review')
        {
            $payment->setAdditionalInformation("stripe_outcome_type", $charge->outcome->type);
        }

        if (!$charge->captured && $this->config->isAutomaticInvoicingEnabled())
        {
            $payment->setIsTransactionPending(true);
            $invoice = $order->prepareInvoice();
            $invoice->register();
            $order->addRelatedObject($invoice);
        }

        $this->paymentIntent->save();
        $object = clone $this->paymentIntent;

        // If this method is called, we should also clear the PI from cache because it cannot be reused
        $this->destroy($order->getQuoteId());

        // This makes sure that if another quote observer is triggered, we do not update the PI
        $this->stopUpdatesForThisSession = true;

        // Create subscriptions if any
        $this->createSubscriptionsFor($order);

        return $object;
    }

    protected function createSubscriptionsFor($order)
    {
        $quote = $this->quoteFactory->create()->load($order->getQuoteId());
        $this->getParamsFrom($quote);
        $cents = 100;
        if ($this->helper->isZeroDecimal($this->params['currency']))
            $cents = 1;

        $returnData = new \Magento\Framework\DataObject();
        $returnData->setAmount($this->params['amount']);
        $returnData->setParams($this->params);
        $returnData->setCents($cents);
        $returnData->setIsDryRun(false);

        $this->eventManager->dispatch('cryozonic_create_subscriptions', array(
            'order' => $order,
            'returnData' => $returnData
        ));
    }

    protected function setOrderState($order, $state)
    {
        $status = $order->getConfig()->getStateDefaultStatus($state);
        $order->setState($state)->setStatus($status);
    }

    public function getDescription()
    {
        if (empty($this->paymentIntent->description))
            return null;

        return $this->paymentIntent->description;
    }

    public function setSource($sourceId)
    {
        if (!$this->shouldUsePaymentIntents())
            return $this;

        $quote = $this->getQuote();

        if (!$quote)
        {
            $this->paymentIntent = null;
            return $this;
        }

        if (!$this->loadFromCache($quote))
            return $this;

        $this->paymentIntent->source = $sourceId;
        $this->updatePaymentIntent($quote);
    }

    public function setPaymentMethod($paymentMethodId, $save = false)
    {
        if (!$this->shouldUsePaymentIntents())
            return $this;

        $quote = $this->getQuote();

        if (!$quote)
        {
            $this->paymentIntent = null;
            return $this;
        }

        if (!$this->loadFromCache($quote))
            return $this;

        $changed = false;

        if (!isset($this->paymentIntent->payment_method) ||
            $this->paymentIntent->payment_method != $paymentMethodId)
        {
            $this->paymentIntent->payment_method = $paymentMethodId;
            $this->setCustomer();
            $changed = true;
        }

        if (!$save && isset($this->paymentIntent->save_payment_method) && $this->paymentIntent->save_payment_method)
        {
            $this->paymentIntent->save_payment_method = false;
            $changed = true;
        }

        if ($save && (!isset($this->paymentIntent->save_payment_method) || !$this->paymentIntent->save_payment_method))
        {
            // Make sure that the card is not already saved
            if (!$this->customer->findCardByPaymentMethodId($paymentMethodId))
            {
                $this->paymentIntent->save_payment_method = true;
                $changed = true;
            }
        }

        if ($changed)
            $this->updatePaymentIntent($quote);

        return $this;
    }

    public function setCustomer()
    {
        $this->customer->createStripeCustomerIfNotExists();

        $customerId = $this->customer->getStripeId();

        if (!$customerId)
            throw new \Exception("Could not find a Stripe customer ID");

        if (!empty($this->paymentIntent->customer) && $this->paymentIntent->customer == $customerId)
            return;

        if (!empty($this->paymentIntent->customer) && $this->paymentIntent->customer != $customerId)
            throw new \Exception("Cannot update Stripe customer once set on the Payment Intent");

        $this->paymentIntent->customer = $this->customer->getStripeId();
    }
}
