<?php

namespace Cryozonic\StripePayments\Api;

interface ServiceInterface
{
    /**
     * Returns Redirect Url
     *
     * @api
     * @return string Redirect Url
     */
    public function redirect_url();

    /**
     * Refunds any dangling PIs for the order and creates a new one for the checkout session
     *
     * @api
     * @param string|null $status
     * @param string|null $response
     *
     * @return mixed Json object containing the new PI ID.
     */
    public function reset_payment_intent($status, $response);

    /**
    * Invalidates the cache for the locally saved Payment Intent
    *
    * @api
    *
    * @return mixed
    */
    public function payment_intent_refresh();
}
