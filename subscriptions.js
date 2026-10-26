(function () {
  'use strict';

  // DOM Elements
  const elPricingSection = document.getElementById('pricing');
  const elGrid = document.getElementById('subs-grid');
  const elLoading = document.getElementById('subs-loading');
  const elEmpty = document.getElementById('subs-empty');
  const elError = document.getElementById('subs-error');
  const btnMonthly = document.getElementById('subs-cycle-monthly');
  const btnYearly = document.getElementById('subs-cycle-yearly');

  let rawPlans = [];
  let currentCycle = 'monthly';

  // Fetch plans.json from the static hosting directory
  async function fetchPlans() {
    try {
      const response = await fetch('plans.json', { cache: 'no-cache' });
      if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);

      const data = await response.json();
      rawPlans = Array.isArray(data) ? data : (data.plans || []);

      if (rawPlans.length === 0) {
        // Hide entire pricing section if no plans
        if (elPricingSection) elPricingSection.style.display = 'none';
        showState('empty');
      } else {
        // Show pricing section if plans exist
        if (elPricingSection) elPricingSection.style.display = 'block';
        renderGrid();
        showState('grid');
      }
    } catch (err) {
      console.error('Failed to load subscription plans:', err);
      // Hide entire pricing section on error
      if (elPricingSection) elPricingSection.style.display = 'none';
      showState('error');
    }
  }

  // Manage section visibility
  function showState(state) {
    if (elLoading) elLoading.hidden = state !== 'loading';
    if (elEmpty) elEmpty.hidden = state !== 'empty';
    if (elError) elError.hidden = state !== 'error';
    if (elGrid) elGrid.hidden = state !== 'grid';
  }

  // Format currency numbers safely
  function formatCurrency(amount) {
    if (amount === undefined || amount === null || isNaN(amount)) return '₹0';
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0
    }).format(amount);
  }

  // Build HTML for plan cards
  function renderGrid() {
    if (!elGrid) return;

    elGrid.innerHTML = '';

    rawPlans.forEach((plan, index) => {
      const isYearly = currentCycle === 'yearly';
      const price = isYearly ? plan.yearlyPrice : plan.monthlyPrice;
      const originalPrice = isYearly ? plan.yearlyOriginalPrice : plan.monthlyOriginalPrice;
      const isPopular = plan.isPopular || plan.popular;

      const card = document.createElement('div');
      card.className = `sub-card ${isPopular ? 'popular' : ''}`;

      let featuresHTML = '';
      if (Array.isArray(plan.features)) {
        featuresHTML = plan.features
          .map(f => `<li><svg width="16" height="16" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/></svg><span>${f}</span></li>`)
          .join('');
      }

      // Build dynamic data attributes for the plan
      const planId = plan.id || `plan-${index}`;
      const planName = plan.name || 'Standard Plan';
      const planPrice = price || 0;
      const planCycle = isYearly ? 'yearly' : 'monthly';
      const planCtaText = plan.ctaText || 'Get Started';

      card.innerHTML = `
        ${isPopular ? '<span class="sub-badge">Most Popular</span>' : ''}
        <h3 class="sub-title">${planName}</h3>
        <p class="sub-desc">${plan.description || ''}</p>

        <div class="sub-price-box">
          ${originalPrice && originalPrice > price ? `<span class="sub-original-price">${formatCurrency(originalPrice)}</span>` : ''}
          <div class="sub-price-row">
            <span class="sub-price">${formatCurrency(price)}</span>
            <span class="sub-period">/${isYearly ? 'year' : 'month'}</span>
          </div>
        </div>

        <button class="btn btn-primary sub-cta" 
                data-cta="register" 
                data-plan-id="${planId}"
                data-plan-name="${planName}"
                data-plan-price="${planPrice}"
                data-plan-cycle="${planCycle}"
                onclick="handlePlanCTA(this)">
          ${planCtaText}
        </button>

        <ul class="sub-features">
          ${featuresHTML}
        </ul>
      `;

      elGrid.appendChild(card);
    });
  }

  // Toggle billing cycle listeners
  function setupCycleToggle() {
    if (!btnMonthly || !btnYearly) return;

    btnMonthly.addEventListener('click', () => {
      if (currentCycle === 'monthly') return;
      currentCycle = 'monthly';
      btnMonthly.classList.add('is-active');
      btnMonthly.setAttribute('aria-selected', 'true');
      btnYearly.classList.remove('is-active');
      btnYearly.setAttribute('aria-selected', 'false');
      renderGrid();
    });

    btnYearly.addEventListener('click', () => {
      if (currentCycle === 'yearly') return;
      currentCycle = 'yearly';
      btnYearly.classList.add('is-active');
      btnYearly.setAttribute('aria-selected', 'true');
      btnMonthly.classList.remove('is-active');
      btnMonthly.setAttribute('aria-selected', 'false');
      renderGrid();
    });
  }

  // Initialize script on DOM ready
  document.addEventListener('DOMContentLoaded', () => {
    setupCycleToggle();
    fetchPlans();
  });
})();

// Global function to handle plan CTA clicks with dynamic data
function handlePlanCTA(button) {
  // Get plan data from button attributes
  const planId = button.getAttribute('data-plan-id');
  const planName = button.getAttribute('data-plan-name');
  const planPrice = button.getAttribute('data-plan-price');
  const planCycle = button.getAttribute('data-plan-cycle');
  
  // You can now use this data for tracking or passing to enterApp
  console.log('Plan selected:', {
    id: planId,
    name: planName,
    price: planPrice,
    cycle: planCycle
  });

  // Call enterApp with plan data
  // Option 1: Pass as JSON string
  const planData = {
    id: planId,
    name: planName,
    price: parseFloat(planPrice),
    cycle: planCycle,
    action: 'register'
  };
  
  // Call enterApp with the plan data
  enterApp();
  
  // For Google Tag Manager tracking
  if (window.dataLayer) {
    window.dataLayer.push({
      'event': 'plan_selected',
      'plan_id': planId,
      'plan_name': planName,
      'plan_price': planPrice,
      'plan_cycle': planCycle
    });
  }
}